Sentry.init do |config|
  config.dsn = "https://4fadcf943f15d1ca6827eb2510f467e0@o4507402586357760.ingest.de.sentry.io/4507402590093392"

  # Without this, Sentry initialises in every environment: test runs and local
  # development send real events to the production project, and each process
  # attempts an HTTPS flush on exit. Beyond the noise, it devalues the alerts we
  # rely on as actual signals — the unauthenticated-webhook warning in
  # VonageWebhookAuthentication being the one that matters most right now.
  config.enabled_environments = %w[production staging]

  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  config.traces_sample_rate = 0.05
  config.profiles_sample_rate = 0.05
end
