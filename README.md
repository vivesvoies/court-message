# Court-message
Envoi et réception de messages (SMS et WhatsApp) pour la médiation numérique.

## Setup

TODO.
1. Commande Docker ou Docker compose pour tout lancer.
2. Commande pour le setup de la db.
3. Commande pour le lancement.

### Lancer avec docker-compose pour le developement

#### Requirements

- Docker
- Docker Compose

#### Installation

```bash
docker-compose build
docker-compose up

# Pour créer migrer et sourcer votre base de données
docker-compose run web rails db:create
docker-compose run web rails db:migrate
docker-compose run web rails db:seed
```

## Linter

Ce projet utilise [omakase](https://github.com/rails/rubocop-rails-omakase) comme linter de **code**.

Pour le lancer, utilisez :

```bash
bundle exec rubocop
```

Pour l'autocorrection, utilisez :

```bash
bundle exec rubocop -a
```
