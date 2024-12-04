require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CourtMessage
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.autoloader = :zeitwerk
    config.load_defaults 7.0

    config.exceptions_app = self.routes

    config.action_dispatch.rescue_responses.merge!(
      "ForbiddenError" => :forbidden
    )
    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    config.i18n.default_locale = :fr
    config.time_zone = "Europe/Paris"
    PhonyRails.default_country_code = "FR"

    config.eager_load_paths << Rails.root.join("app", "providers")

    # From https://docs.sendgrid.com/for-developers/sending-email/rubyonrails
    config.action_mailer.smtp_settings = {
      user_name: "apikey", # This is the string literal "apikey", NOT the ID of your API key
      password: Rails.application.credentials.sendgrid_api_key, # This is the secret sendgrid API key which was issued during API key creation
      domain: "court-message.fr",
      address: "smtp.sendgrid.net",
      port: 587,
      authentication: :plain,
      enable_starttls_auto: true
    }
  end
end
