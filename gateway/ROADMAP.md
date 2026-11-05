# Gateway SMS — conception, état et reste à faire

Document de cadrage de la branche `sms-gateway` (non encore fusionnée dans
`main`). Pour l'installation et l'exploitation, voir [README.md](README.md).

Estimations : **XS** < 30 min · **S** ≈ 1 h · **M** 2-4 h · **L** ≥ 1 jour.

---

## 1. Ce que la branche livre

L'objectif : envoyer et recevoir des SMS via une carte SIM dans un appareil
que nous contrôlons (Raspberry Pi + modem 4G), avec Vonage en secours.

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

Mécanismes :

- **Réclamation atomique** (`FOR UPDATE SKIP LOCKED`) : plusieurs gateways ou
  plusieurs modems ne peuvent pas envoyer le même message deux fois. Un
  message réclamé mais non confirmé redevient réclamable après 10 min.
- **Supervision** : heartbeat par modem (signal, état réseau, erreur) +
  `rake sms_gateway:check_health` (cron) qui alerte Sentry sur Pi injoignable,
  modem HS, file bloquée, réclamations sans accusé, rafales d'échecs, lignes
  orphelines.
- **Bascule vers Vonage**, à deux niveaux :
  - *au routage* : tant que le gateway ne poll plus (2 min) ou que son modem
    ne se déclare pas sain, les nouveaux messages partent directement par la
    ligne de secours ;
  - *après coup* : `rake sms_gateway:failover` (cron) re-route les messages
    restés en file au-delà de `fallback_after_minutes` et ceux dont le modem
    a rapporté l'échec. Jamais les réclamés non confirmés (risque de
    doublon), qui déclenchent une alerte.
- **Résilience du Pi** : pas d'envoi sans enregistrement réseau, watchdog
  systemd contre les appels gammu figés, réinitialisation USB automatique du
  modem (`cm-modem-reset`) quand le noyau l'a perdu.

---

## 2. État de validation (2026-11-05)

| Élément | État |
|---|---|
| Suite de tests applicative (+ tests système) | ✅ 313 + 12, 0 échec |
| Tests unitaires du démon (sans modem) | ✅ 11, en CI |
| Pi 4 `cm-gateway` provisionné (Debian 13, gammu, udev, Tailscale) | ✅ |
| Enregistrement réseau (Orange, itinérance nationale de la SIM Free) | ✅ |
| Envoi + réception SMS réels avec gammu sur le Pi | ✅ (29/08, 05/11) |
| Démon ↔ application (bout en bout) : envoi + réponse réels | ✅ 05/11, Pi → app de dev sur le LAN, ~5 s par envoi |
| Bascule Vonage observée en conditions réelles | ✅ 05/11, les deux voies : file re-routée par `failover` après `fallback_after_minutes`, et routage direct après 2 min de silence du Pi |
| Réinitialisation USB automatique | ✅ 05/11, modem dés-autorisé : de retour en 35 s sans intervention |
| `install.sh` (installation puis mise à jour) | ✅ 05/11, config conservée |

---

## 3. Reste à faire avant la mise en production

| # | Tâche | Effort |
|---|---|---|
| B6 | **Vérifier que `cron.json` est pris en compte** par le scheduler Scalingo après déploiement (`scalingo cron-tasks`), sinon ni supervision ni bascule après coup. | S |
| B7 | **Fusionner** dans `main` et jouer les migrations (staging puis production). | S |
| B8 | **Configurer la production** : `rake sms_gateway:provision` + `add_line` (SIM `+33743782865`), ligne de secours = ligne Vonage par défaut, `fallback_after_minutes`, rattacher l'équipe ; puis `url` et `token` de prod dans `/etc/cm-sms-gateway.conf` sur le Pi. | S |

Fait depuis le cadrage d'août : B1 (pas d'envoi sans enregistrement), B2
(réinitialisation USB), B3 (ligne Vonage par défaut en base), B4 (bout en
bout, bascule comprise), B5 (SMS réels sur le Pi).

---

## 4. Sécurité

| # | Tâche | Effort |
|---|---|---|
| S2 | Remplacer le parsing manuel de l'en-tête `Bearer` par `authenticate_with_http_token` (déjà fourni par `ActionController::API`). | S |

S1 (webhooks Vonage non authentifiés) est réglé sur `main` (#440).

---

## 5. Qualité (constats de revue, non bloquants)

| # | Tâche | Effort |
|---|---|---|
| Q2 | `ALLOWED_STATUSES` recopie une partie de l'enum `Message` : à dériver de l'enum pour éviter la dérive. | S |
| Q3 | `touch_last_seen!` écrit une ligne à chaque requête du gateway (≈ 1 écriture / 10 s / modem, indéfiniment). À limiter à ~1/min. | S |
| Q4 | `ProviderResult#raw` n'est jamais lu : à supprimer. | XS |
| Q5 | `formatted_phone` est identique dans `Contact` et `PhoneLine` : à mutualiser. | XS |
| Q6 | Retirer `PhoneLine.legacy_number` maintenant que la ligne par défaut existe en base (deux sources de vérité pour le numéro d'envoi). | S |

Q1 (persistance des entrants dupliquée) est fait : tout passe par
`InboundMessagesService#save`.

---

## 6. Matériel et exploitation

| # | Tâche |
|---|---|
| O1 | **Antenne externe** sur le plot u.FL `MAIN` (700 MHz B28 + 1800 MHz B3), pour la marge. L'antenne interne suffit sur le site actuel. |
| O2 | **USB** : le modem est branché directement sur le hub interne du Pi 4 (aucun hub externe n'apparaît sur le bus). Le port 4 refuse le modem depuis le choc du 30/10 ; il est sur le port 3 depuis le 05/11, stable. Surveiller `dmesg` et `journalctl -u cm-modem-reset`. |
| O3 | **Relevé de couverture sur le site de déploiement** avant de s'engager (`gateway/scan-here.py` sur le banc, ou un téléphone avec la SIM). |
| O6 | **Forfait de la SIM** : vérifier que les conditions d'usage autorisent un usage automatisé (passerelle). |

---

## 7. Plus tard (optionnel)

| # | Piste |
|---|---|
| F1 | **Latence d'envoi.** Le polling à 10 s ajoute ~5 s en médiane. Si cela devient gênant : sonnette Action Cable (le Pi ouvre un WebSocket, l'app diffuse un simple « réveille-toi », le Pi réclame ensuite par HTTP). Ne pas remplacer le pull par du push. |
| F2 | **Messages entrants orphelins.** Un SMS d'un expéditeur inconnu n'est persisté nulle part : l'app répond 422 et le démon journalise le contenu puis efface de la SIM. Vrai aussi côté Vonage (400). |
| F3 | **Contact présent dans plusieurs équipes** : non géré (TODO antérieur). |
| F4 | **Coupure d'alimentation du port USB** (`uhubctl`) en dernier recours, si un jour le modem se fige sans disparaître du bus. |
