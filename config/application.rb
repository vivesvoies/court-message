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

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.i18n.default_locale = :fr
    config.time_zone = "Europe/Paris"
    PhonyRails.default_country_code = "FR"

    # Add this line for Rails 8.1 deprecation warning
    config.active_support.to_time_preserves_timezone = :zone

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
