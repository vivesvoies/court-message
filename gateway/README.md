# Gateway SMS (modem SIM sur Raspberry Pi)

Ce dossier contient le démon qui permet à CM d'envoyer et de recevoir des
SMS via une carte SIM installée dans un appareil que nous contrôlons
(typiquement un Raspberry Pi avec un modem USB), en complément ou en
remplacement de Vonage.

## Architecture

```
             HTTPS sortant uniquement (token Bearer)
┌─────────────┐         POST /gateway/v1/messages/claims        ┌──────────────┐
│ Raspberry Pi │ ──────────────────────────────────────────────▶ │  App CM      │
│  + modem SIM │ ◀───── liste des messages à envoyer ─────────── │  (Scalingo)  │
│ (ce démon)   │                                                 │              │
│              │ ── PATCH /gateway/v1/messages/:uuid (statut) ─▶ │              │
│              │ ── POST  /gateway/v1/inbound_messages (reçus) ▶ │              │
│              │ ── POST  /gateway/v1/heartbeat (santé modem)  ▶ │              │
└─────────────┘                                                 └──────────────┘
```

Le gateway **n'ouvre aucun port** : c'est lui qui interroge l'application
(*pull*). Il fonctionne donc derrière n'importe quelle box/NAT/4G, sans
redirection de port ni IP fixe. À chaque cycle il envoie aussi un
*heartbeat* (`POST /gateway/v1/heartbeat`) qui rapporte l'état du modem
(joignable ou non, force du signal, état réseau) pour la ligne qu'il pilote.

Côté application :

- un `SmsGateway` représente un appareil (un Raspberry Pi) et détient un
  token d'API (stocké haché) ;
- une `PhoneLine` représente un numéro d'expéditeur et son opérateur :
  `vonage` (API) ou `sms_gateway` (une SIM d'un de nos gateways) ;
- une `Team` peut être rattachée à une `PhoneLine` (sinon la ligne par
  défaut, sinon le numéro Vonage historique). Les messages sortants d'une
  équipe partent par la ligne de l'équipe ;
- les messages sortants d'une ligne `sms_gateway` restent en statut
  `unsent` jusqu'à ce que le gateway les réclame (*claim*) puis confirme
  l'envoi (`submitted`/`failed`). Un message réclamé mais jamais confirmé
  redevient réclamable après 10 minutes ;
- une `PhoneLine` peut être désactivée (`active: false`, par exemple depuis
  Avo) et désigner une **ligne de secours** (`fallback_phone_line`, elle
  aussi une `PhoneLine`, donc Vonage ou une autre SIM). Un délai optionnel
  (`fallback_after_minutes`) déclenche une **bascule automatique** des
  messages restés en attente trop longtemps vers cette ligne de secours,
  même quand la ligne d'origine reste active (voir plus bas).

## Sécurité

- **Authentification** : chaque requête porte `Authorization: Bearer <token>`.
  Le token (256 bits aléatoires) est émis une seule fois au provisionnement ;
  seule son empreinte SHA-256 est stockée en base. Rotation possible à tout
  moment (`rake sms_gateway:rotate_token[nom]`).
- **Transport** : TLS via l'HTTPS public de l'application. Le démon vérifie
  les certificats (comportement par défaut de `requests`).
- **Tailscale (optionnel)** : si vous souhaitez ne pas exposer ces échanges
  sur l'URL publique, installez Tailscale sur le Pi et faites pointer `url`
  vers une adresse joignable par le tailnet. Côté Scalingo, l'app ne peut
  pas rejoindre un tailnet nativement ; le protocole étant du simple HTTPS
  sortant, il fonctionne indifféremment en direct ou à travers un tunnel.
  Le token + TLS suffisent sans Tailscale.
- **Portée des tokens** : un gateway ne peut réclamer/mettre à jour que les
  messages de ses propres lignes, et les statuts acceptés sont limités à une
  liste blanche.
- **Messages entrants** : ils ne sont supprimés de la SIM qu'une fois que
  l'application les a acceptés — une panne réseau ne perd aucun SMS.
- **Rejets définitifs** : quand l'application refuse un SMS entrant de façon
  définitive (par exemple expéditeur inconnu), son contenu complet est
  d'abord journalisé dans journald, avant suppression de la SIM — c'est la
  seule copie qui en subsiste.

## Matériel

- Raspberry Pi (n'importe quel modèle avec USB) ;
- un modem GSM/4G géré par [gammu](https://wammu.eu/gammu/) : clé USB type
  Huawei E3372 (en mode modem/« stick »), module SIM800/SIM7600, etc. ;
- une carte SIM avec un forfait SMS.

## Installation sur le Pi

```bash
sudo apt update
sudo apt install gammu python3-gammu python3-requests

# Configurer gammu pour votre modem (crée /etc/gammurc ou ~/.gammurc) :
sudo gammu-config     # device: /dev/ttyUSB0 (par ex.), connection: at
sudo gammu identify   # vérifie que le modem répond
```

### 1. Provisionner le gateway côté app (une fois)

Sur Scalingo :

```bash
scalingo --app <app> run bundle exec rake "sms_gateway:provision[raspi-mediation]"
# → affiche le token d'API (une seule fois !)

scalingo --app <app> run bundle exec rake "sms_gateway:add_line[raspi-mediation,+33612345678]"
```

Puis rattacher la ligne à une équipe (champ « phone line » de la team dans
Avo) ou la marquer `default` pour qu'elle serve de ligne par défaut.

### 2. Installer le démon

```bash
sudo mkdir -p /opt/cm-sms-gateway
sudo cp cm_sms_gateway.py /opt/cm-sms-gateway/
sudo cp cm-sms-gateway.conf.example /etc/cm-sms-gateway.conf
sudo chmod 600 /etc/cm-sms-gateway.conf
sudo nano /etc/cm-sms-gateway.conf   # url, token, line_phone

sudo useradd --system --no-create-home cm-gateway
sudo cp cm-sms-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now cm-sms-gateway
journalctl -u cm-sms-gateway -f
```

## Plusieurs Raspberry Pi, plusieurs SIM

- **Plusieurs Pi** : provisionner un `SmsGateway` (donc un token) par
  appareil. Chaque Pi ne voit que les messages de ses propres lignes.
- **Plusieurs SIM sur un même Pi** : déclarer chaque numéro avec
  `sms_gateway:add_line`, configurer une section gammu par modem
  (`[gammu]`, `[gammu1]`, ... dans `/etc/gammurc`), puis lancer une instance
  du démon par modem avec son propre fichier de configuration
  (`line_phone` + `gammu_section` distincts). Le démon passe `line_phone`
  au *claim*, chaque instance ne réclame donc que les messages de sa ligne.
- La répartition métier se fait côté app : chaque équipe est rattachée à la
  ligne (Vonage ou SIM) qui doit porter ses messages.

## Supervision

- **Heartbeat modem** : à chaque cycle, le démon rapporte l'état du modem
  (`modem_ok`, force du signal, état réseau, ou le message d'erreur gammu le
  cas échéant) via `POST /gateway/v1/heartbeat`. Ces informations sont
  stockées sur la `PhoneLine` (`modem_ok`, `modem_details`,
  `last_modem_check_at`) et visibles directement dans Avo sur la fiche de la
  ligne. `SmsGateway#last_seen_at` (aussi visible dans Avo) est mis à jour à
  chaque requête du gateway, quel que soit son type : une valeur ancienne
  signale un Pi injoignable (réseau coupé, daemon arrêté), à distinguer d'un
  Pi vivant mais dont le modem est en panne (`modem_ok` à `false`).
- **Tâche cron `sms_gateway:check_health`** (Scalingo, toutes les 10 minutes,
  voir `cron.json`) : exécute `SmsGatewayHealthService`, qui détecte et
  envoie une alerte Sentry (+ log) pour chacun des cas suivants :
  - un Pi injoignable (`last_seen_at` trop ancien sur un gateway qui porte
    une ligne active) ;
  - un modem en panne sur une ligne dont le Pi répond pourtant (`modem_ok`
    à `false`, ou heartbeat modem trop ancien) ;
  - des messages en attente jamais réclamés par un gateway au-delà d'un
    certain délai (la ligne est bloquée côté Pi) ;
  - des messages réclamés mais jamais confirmés (le modem a peut-être déjà
    envoyé le SMS : risque de doublon, une intervention manuelle est
    nécessaire — ces messages ne sont jamais basculés automatiquement) ;
  - des rafales d'échecs d'envoi récents sur une ligne ;
  - des lignes `sms_gateway` actives sans gateway rattaché (lignes
    orphelines : les messages qui y sont déposés ne seront jamais envoyés).
- **Dead-man's switch optionnel (`healthcheck_url`)** : si le fichier de
  configuration du Pi renseigne `healthcheck_url` (ex. un endpoint
  healthchecks.io), le démon le ping après chaque cycle réussi. Cela permet
  de surveiller que le service tourne toujours indépendamment du reporting
  applicatif (utile si l'app elle-même est injoignable).
- **Journal des envois (`state_file`)** : le démon tient un journal local
  (par défaut `/var/lib/cm-sms-gateway/state.json`) des messages déjà remis
  au modem mais pas encore confirmés à l'application. En cas de crash ou de
  redémarrage entre l'envoi et l'accusé de réception, ce journal évite de
  renvoyer deux fois le même SMS : au redémarrage, le démon retente
  uniquement l'accusé de réception pour les entrées en attente.
- Les statuts des messages (`unsent` → `submitted` → `delivered`/`failed`)
  suivent le cycle habituel, alimenté ici par le démon.

## Bascule vers une autre ligne (fallback)

Une `PhoneLine` peut désigner une ligne de secours (`fallback_phone_line`),
qui peut être Vonage **ou** la SIM d'un autre Raspberry Pi. Cela permet de
continuer à envoyer les messages d'une équipe même quand sa ligne habituelle
est en panne ou désactivée.

- **Configuration** : dans Avo, sur la fiche de la `PhoneLine`, renseigner
  le champ « Ligne de secours » (`fallback_phone_line`) et, pour activer la
  bascule automatique, un délai « Bascule auto après (minutes) »
  (`fallback_after_minutes`). Sans délai renseigné, seule la bascule
  manuelle (désactivation) déclenche un renvoi.
- **Bascule automatique** : la tâche cron Scalingo `sms_gateway:failover`
  (toutes les 10 minutes, voir `cron.json`) exécute
  `MessageFallbackService`, qui ne re-route que les messages pour lesquels
  un double envoi est impossible :
  - les messages en attente **jamais réclamés** par un gateway, restés
    dans la file au-delà du délai configuré (ou immédiatement si la ligne a
    été désactivée) ;
  - les messages dont l'envoi a été **rapporté en échec** par le modem (le
    SMS n'est pas parti), dans les 24 heures suivant l'échec.

  Les messages **réclamés mais jamais confirmés** ne sont volontairement
  jamais basculés : le SMS a peut-être déjà quitté le modem, et le renvoyer
  risquerait un doublon. Ce cas déclenche une alerte via
  `sms_gateway:check_health` pour qu'un humain tranche.
- **Bascule manuelle** : depuis Avo, l'action « Désactiver et basculer vers
  la ligne de secours » (`Avo::Actions::FailOverPhoneLine`) désactive la
  ligne et bascule immédiatement ses messages en attente et ses échecs vers
  la ligne de secours. On peut aussi se contenter de désactiver la ligne
  (champ « Active ») et laisser la tâche cron `sms_gateway:failover`
  s'en charger au prochain passage.
- Tant qu'une ligne est désactivée, `PhoneLine.route_for` dirige
  directement les nouveaux messages de ses équipes vers sa ligne de secours
  (à défaut, vers la ligne par défaut).
