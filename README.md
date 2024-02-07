# Court-message
Envoi et réception de messages (SMS et WhatsApp) pour la médiation numérique.

## Setup

### Lancer le projet avec docker-compose pour le developement

#### Requirements

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

#### Installation

```bash
docker-compose build
docker-compose up

# Pour créer migrer et sourcer votre base de données
docker-compose run web rails db:create
docker-compose run web rails db:migrate
docker-compose run web rails db:seed
```

### Lancer le projet en local pour le developement

#### Requirements

- [Docker](https://docs.docker.com/get-docker/)
- [Ruby](https://www.ruby-lang.org/) `3.3.0`.
    Vous pouvez utilisez [rbenv](https://github.com/rbenv/rbenv).
- [Postgresql client](https://www.dewanahmed.com/install-psql/).
- libpq

#### Installation

**Postgres DB**
```bash
docker run -p 5432:5432 --name database -e POSTGRES_PASSWORD=password -e POSTGRES_DB=cm_development postgres:16.1-alpine
```

Au premier lancement vous aurez besoin d'installer les dépendances du projet et de mettre en place votre base de données:

```bash
bundle install # Installer les dépendances
rails db:create # Créer la base de données
rails db:migrate # Appliquer les migrations
rails db:seed # Optionel: À lancer si vous souhaitez sourcer votre base de données avec le fichier db/seeds.rb
```

**Redis**
```bash
docker run -p 6379:6379 --name redis redis:7.2.4-alpine
```

**App**
Maintenant vous pouvez lancer votre app à l'aide de cette commande:

```bash
rails server
```

Elle sera disponible à cette url `http://127.0.0.1:3000`

## Tests

### Avec docker-compose:

```bash
docker-compose run web rails test
```

### Avec le server local

**Créer un réseau**
```bash
docker network create grid
```

**Selenium Hub**
```bash
docker run -p 4442:4442 -p 4443:4443 -p 4444:4444  --net grid --name selenium-hub selenium/hub:4.17
```

**Selenium Chrome**
```bash
docker run -p 5900-5902:5900 -e SE_EVENT_BUS_HOST=selenium-hub -e SE_EVENT_BUS_PUBLISH_PORT=4442 -e SE_EVENT_BUS_SUBSCRIBE_PORT=4443 --net grid --name selenium-chrome selenium/node-chrome:120.0
```

```bash
rails test
```

Pensez à le supprimer notre réseau par la suite:

```bash
docker network rm grid
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
