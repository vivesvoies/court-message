source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.1.3"

gem "rails", "~> 7.0.4"

gem "pg", "~> 1.4"
gem "puma", "~> 5.0"
gem "redis", "~> 4.0"
gem "sprockets-rails"

gem "bootsnap", require: false

gem "importmap-rails", "~> 1.1"
gem "stimulus-rails"
gem "turbo-rails"
# gem "sassc-rails"

gem "bcrypt", "~> 3.1.7"

# Specify a precise version because
# the bundled one had vulnerabilities.
gem "nokogiri", "~> 1.13.10"

# Look for security vulnerabilities
gem "brakeman"

# Check dependencies for vulnerabilities
gem "bundler-audit"

# lograge changes Rails' logging to a more
# traditional one-line-per-event format
gem "lograge"

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "factory_bot_rails"
  gem "faker"
  gem "minitest-reporters"
end

group :development do
  gem "annotate"
  gem "rack-mini-profiler"
  gem "rubocop"
  gem "rubocop-minitest", require: false
  gem "rubocop-rails", require: false
  # gem "web-console"
  gem "better_errors"
  gem "binding_of_caller"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

### Defaults and suggestions from the Rails template:

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# gem "jsbundling-rails"
# gem "cssbundling-rails"
