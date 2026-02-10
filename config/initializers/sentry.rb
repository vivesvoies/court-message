Sentry.init do |config|
  config.dsn = "https://4fadcf943f15d1ca6827eb2510f467e0@o4507402586357760.ingest.de.sentry.io/4507402590093392"
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  config.traces_sample_rate = 0.05
  config.profiles_sample_rate = 0.05
end
