# Court-message
Envoi et réception de messages (SMS et WhatsApp) pour la médiation numérique.

## Lancer le projet avec docker-compose pour le developement

### Setup

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

### Tests

```bash
docker-compose run web rails test
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

## Lancer le projet en local pour le developement

### Setup

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


### Tests

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

## Lancer une instance manuellement

Les instructions qui suivent sont optimisées pour un hébergeur PaaS comme Scalingo ou Heroku, mais d'autres hébergements sont possibles.

### Prérequis

- Une clé d'API SendGrid.
- Une clé d'API Vonage ou d'un autre opérateur, à noter que ce projet utilise Vonage et ne prend pour l'instant pas en charge d'autres opérateurs.
   Une fois votre clé crée ajouter la à vos credentials rails sous le nom `vonage_private_key` via la command:
   ```
   EDITOR=vim rails credentials:edit
   ```
   Vous pouvez vérifiez dans la console rails que la clé est bien accessible via la commande:
   ```
   Rails.application.credentials.vonage_private_key
   ```

### Étapes

1. **Créer une clé API SendGrid :**
   Vous pouvez obtenir une clé API SendGrid en vous inscrivant sur leur site web et en créant un compte. Une fois connecté à votre compte SendGrid, accédez à l'onglet "Settings" (Paramètres) et cliquez sur "API Keys" (Clés API) pour en créer une nouvelle.

2. **Créer une clé API Vonage :**
   De même, pour obtenir une clé API d'un opérateur, vous devez vous inscrire sur leur site web, créer un compte et générer une clé API dans votre tableau de bord.

3. **Créer une nouvelle application sur un fournisseur de services cloud :**
   - Choisissez un fournisseur de services cloud comme Scalingo, Heroku ou un autre.
   - Créez une nouvelle application sur la plateforme cloud choisie.
   - Ajoutez les addons nécessaires à votre application
      - Postgres
      - Redis

4. **Configurer les variables d'environnement :**
   - Une fois que votre application est créée, accédez à son tableau de bord sur le fournisseur de services cloud.
   - Configurez les variables d'environnement suivantes :
     - `SENDGRID_API_KEY` : `ma_cle_sengrid`
     - `VONAGE_APPLICATION_ID` : `ma_cle_vonage`
     - `RAILS_MASTER_KEY` : `ma_cle_rails`

5. **Déploiement de l'application :**
   - Déployez votre application sur la plateforme cloud en suivant les instructions spécifiques au fournisseur que vous avez choisi.

Une fois que toutes ces étapes sont terminées, votre instance de l'application devrait être opérationnelle.
