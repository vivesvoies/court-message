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
└─────────────┘                                                 └──────────────┘
```

Le gateway **n'ouvre aucun port** : c'est lui qui interroge l'application
(*pull*). Il fonctionne donc derrière n'importe quelle box/NAT/4G, sans
redirection de port ni IP fixe.

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
  redevient réclamable après 10 minutes.

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

- `SmsGateway#last_seen_at` (visible dans Avo) est mis à jour à chaque
  requête du gateway : une valeur ancienne signale un Pi injoignable.
- Les statuts des messages (`unsent` → `submitted` → `delivered`/`failed`)
  suivent le cycle habituel, alimenté ici par le démon.
