# Gateway SMS — conception, état et reste à faire

Document de cadrage pour la branche `claude/sim-modem-provider-raspi-pqnol9`
(non encore fusionnée dans `staging`). Pour l'installation et l'exploitation,
voir [README.md](README.md).

Estimations : **XS** < 30 min · **S** ≈ 1 h · **M** 2-4 h · **L** ≥ 1 jour.

---

## 1. Ce que la branche livre

L'objectif : envoyer et recevoir des SMS via une carte SIM dans un appareil
que nous contrôlons (Raspberry Pi + modem 4G), en complément ou en
remplacement de Vonage.

**Choix de conception structurant : le gateway *tire* le travail (pull).**
Le Pi n'ouvre aucun port ; il interroge l'application en HTTPS sortant. Il
fonctionne donc derrière n'importe quel NAT/4G, sans IP fixe ni redirection,
et Scalingo n'a rien à joindre. C'est aussi ce qui rend Tailscale optionnel
plutôt que nécessaire.

Modèle de données :

| Objet | Rôle |
|---|---|
| `SmsGateway` | un appareil (un Pi), porte un token d'API haché |
| `PhoneLine` | un numéro d'expéditeur + son opérateur (`vonage` ou `sms_gateway`) |
| `Team.phone_line` | routage : les messages d'une équipe partent par sa ligne |
| `Message.phone_line` | ligne effectivement utilisée, pour le suivi et la bascule |

Trois mécanismes en découlent :

- **Réclamation atomique** (`FOR UPDATE SKIP LOCKED`) : plusieurs gateways ou
  plusieurs modems ne peuvent pas envoyer le même message deux fois. Un
  message réclamé mais non confirmé redevient réclamable après 10 min.
- **Supervision** : heartbeat par modem (signal, état réseau, erreur) +
  `rake sms_gateway:check_health` (cron) qui alerte Sentry sur Pi injoignable,
  modem HS, file bloquée, réclamations sans accusé, rafales d'échecs, lignes
  orphelines.
- **Bascule** : une ligne peut désigner une ligne de secours (Vonage ou une
  autre SIM), manuelle (action Avo) ou automatique (`fallback_after_minutes`).
  Ne bascule **que** les messages jamais réclamés ou en échec modem — jamais
  les réclamés non confirmés (risque de doublon), qui déclenchent une alerte.

---

## 2. État de validation

Testé sur un banc OrbStack (VM Debian 13 arm64 + Quectel EC25-EUX en USB)
tenant lieu de Raspberry Pi en attendant la carte SD.

| Élément | État |
|---|---|
| Suite de tests applicative | ✅ 291 tests, 0 échec |
| Passthrough USB, pilote `option`, ports série | ✅ |
| gammu ↔ modem (identify, IMEI, IMSI) | ✅ |
| Carte SIM Free | ✅ (SMS envoyé depuis un téléphone) |
| Chaîne RF (réception, scan réseau) | ✅ −75 dBm mesuré |
| **Enregistrement réseau + envoi SMS réel** | ❌ **jamais réussi** |
| Daemon ↔ application (bout en bout) | ❌ jamais lancé contre staging |

**Le seul maillon non prouvé est le dernier saut radio.** L'échec est
d'origine environnementale (couverture Free marginale sur le lieu de test,
antenne interne médiocre), pas logicielle. À refaire sur un site couvert.

---

## 3. Bloquant avant mise en production

| # | Tâche | Effort |
|---|---|---|
| B1 | **Garde-fou sur l'envoi bloquant.** `modem.send()` n'a pas de timeout : modem non enregistré → gammu bloque indéfiniment, le cycle se fige, plus de heartbeat ni de réception. Le correctif n'est pas un timeout mais un **contrôle d'enregistrement avant la boucle d'envoi** : si non enregistré, ne rien tenter, laisser les messages en file et remonter `modem_ok: false`. La supervision et la bascule Vonage existantes prennent alors le relais. | S |
| B2 | **Récupération d'un modem planté.** Constaté 3 fois pendant les tests. `Init()` de gammu ne suffit pas, et `orb usb detach/attach` non plus : seul un débranchement physique réanime le modem. Équivalent logiciel : unbind/bind via `/sys/bus/usb/drivers/usb/`, qui force une ré-énumération. Indispensable pour un appareil sans intervention humaine. | M |
| B3 | **Ligne par défaut en base.** Sans `PhoneLine` marquée `default`, les messages partent par `PhoneLine.legacy_number` (constante par environnement) avec `phone_line` à `nil` : ni attribution, ni routage, ni bascule. Prévoir une migration de données / seed pour les 3 environnements. | S |
| B4 | **Test d'intégration contre staging.** Ne nécessite pas de modem enregistré : valide l'authentification, le heartbeat, la réclamation, le journal d'envoi, le chemin d'échec et la bascule automatique vers Vonage. | M |
| B5 | **Test SMS réel** (émission + réception) depuis un site couvert. | M |
| B6 | **Vérifier que `cron.json` est bien pris en compte** par le scheduler Scalingo (sinon ni supervision ni bascule automatique). | S |
| B7 | **Fusionner la branche** dans `staging` (2 commits, jamais fusionnés) et jouer les migrations. | S |

---

## 4. Sécurité

| # | Tâche | Effort |
|---|---|---|
| S1 | **Les webhooks Vonage historiques restent non authentifiés.** `authenticate_message!` ne fait que logger un avertissement, et `outbound_messages#create` accepte n'importe quel statut sans vérification. Antérieur à cette branche, mais il y a désormais deux chemins d'ingestion : l'un authentifié, l'autre non. | M |
| S2 | Remplacer le parsing manuel de l'en-tête `Bearer` par `authenticate_with_http_token` (déjà fourni par `ActionController::API`). | S |

---

## 5. Qualité (constats de revue, non bloquants)

| # | Tâche | Effort |
|---|---|---|
| Q1 | La persistance des messages entrants est dupliquée entre `InboundMessagesController` et `Gateway::V1::InboundMessagesController`. À extraire dans `InboundMessagesService` — c'est aussi là que devra vivre toute évolution d'idempotence. | S |
| Q2 | `ALLOWED_STATUSES` recopie une partie de l'enum `Message` : à dériver de l'enum pour éviter la dérive. | S |
| Q3 | `touch_last_seen!` écrit une ligne à chaque requête du gateway (≈ 1 écriture / 10 s / modem, indéfiniment). À limiter à ~1/min. | S |
| Q4 | `ProviderResult#raw` n'est jamais lu : à supprimer (il réintroduit l'objet Vonage que cette classe sert justement à masquer). | XS |
| Q5 | `formatted_phone` est identique dans `Contact` et `PhoneLine` : à mutualiser. | XS |
| Q6 | Retirer `PhoneLine.legacy_number` une fois B3 fait (deux sources de vérité pour le numéro d'envoi). | S |

---

## 6. Hygiène dépôt

| # | Tâche | Effort |
|---|---|---|
| H1 | Committer `gateway/cloud-init.yml` (actuellement non suivi) — c'est la recette reproductible du banc de test. | XS |
| H2 | `lib/tasks/auto_annotate_models.rake` fait `require "annotate"` alors que le Gemfile fournit `annotaterb` : **toute commande rake échoue en développement**. Antérieur à cette branche. | XS |

---

## 7. Matériel et exploitation

Hors code, mais conditionne la fiabilité en production.

| # | Tâche |
|---|---|
| O1 | **Antenne externe** sur le plot u.FL `MAIN` (700 MHz B28 + 1800 MHz B3). L'antenne FPC interne est le facteur limitant constaté : un téléphone passe là où le dongle ne voit rien. |
| O2 | **Alimentation USB correcte.** Les plantages du modem ont cessé après changement de hub. Prévoir un hub alimenté et une alimentation Pi officielle — la sous-tension est la première cause d'instabilité sur Pi. |
| O3 | **Relevé de couverture sur le site de déploiement avant de s'engager** (`gateway/scan-here.py` sur le banc, ou un téléphone avec la SIM). Free a la couverture la plus mince des quatre opérateurs. |
| O4 | Carte SD 64 Go *High Endurance*, `journald` plafonné, swap désactivé — ou, mieux pour du 24/7, démarrage sur SSD USB. |
| O5 | Provisionner le Pi (en attente de la carte SD). |

---

## 8. Plus tard (optionnel)

| # | Piste |
|---|---|
| F1 | **Latence d'envoi.** Le polling à 10 s ajoute ~5 s en médiane. Si cela devient gênant : sonnette Action Cable (le Pi ouvre un WebSocket, l'app diffuse un simple « réveille-toi », le Pi réclame ensuite par HTTP). La réclamation reste la source de vérité, donc la sonnette peut être perdue sans conséquence. Ne pas remplacer le pull par du push. |
| F2 | **Messages entrants orphelins.** Un SMS d'un expéditeur inconnu n'est persisté nulle part : l'app répond 422 et le daemon journalise le contenu puis efface de la SIM. TODO déjà présent dans le code. |
| F3 | **Contact présent dans plusieurs équipes** : non géré (TODO antérieur). |

---

## 9. Séquencement suggéré

1. **Débloquer sans matériel** : B1, B3, B4, B6, H1, H2 — puis B7 (fusion).
   Rien là-dedans n'attend le Pi ni la couverture.
2. **Quand un site couvert est disponible** : B5, puis B2 (dont le test
   dépend de la capacité à faire planter un modem).
3. **Avant exposition réelle** : S1 — deux chemins d'ingestion dont un non
   authentifié, c'est le point faible restant.
4. **En continu / à l'occasion** : Q1-Q6.
5. **Matériel** : O1-O5 en parallèle, indépendants du code.
