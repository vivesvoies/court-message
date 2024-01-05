source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0"

gem "rails", "~> 7.1.2"

gem "pg", "~> 1.5"
gem "puma", "~> 6.4"
gem "redis", "~> 5.0"
gem "sprockets-rails"

gem "bootsnap", require: false

gem "hotwire-livereload", "~> 1.3"
gem "importmap-rails", "~> 2.0"
gem "sass-rails"
gem "stimulus-rails"
gem "turbo-rails"

gem "bcrypt", "~> 3.1.20"
gem "brakeman" # Look for security vulnerabilities
gem "bundler-audit" # Check dependencies for vulnerabilities
gem "cancancan"
gem "devise", "~> 4.9"
gem "devise-i18n"
gem "lograge" # One-line-per-event format logs
gem "phony_rails"
gem "rails-i18n", "~> 7.0.8"

gem "vonage", "~> 7.19"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "factory_bot_rails"
  gem "faker"
  gem "minitest-reporters"
end

group :development do
  gem "annotate"
  gem "rack-mini-profiler"
  gem "standard", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-rails", require: false
  # gem "web-console"
  gem "better_errors"
  gem "binding_of_caller"
end

group :test do
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "selenium-webdriver"
  gem "webdrivers"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]

### Defaults and suggestions from the Rails template:

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem "jbuilder"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# gem "jsbundling-rails"
# gem "cssbundling-rails"
