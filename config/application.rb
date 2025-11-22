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

    config.active_support.to_time_preserves_timezone = :zone

    config.eager_load_paths << Rails.root.join("app", "providers")

    # From https://docs.sendgrid.com/for-developers/sending-email/rubyonrails

    config.action_mailer.smtp_settings = {
      user_name: Rails.application.credentials.brevo_smtp_login,
      password: Rails.application.credentials.brevo_smtp_key,
      domain: "court-message.fr",
      address: "smtp-relay.brevo.com",
      port: 587,
      authentication: :plain,
      enable_starttls_auto: true
    }
  end
end
