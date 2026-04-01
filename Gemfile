source "https://gem.coop"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "4.0.1"

gem "rails", "~> 8.1.0"

gem "pg", "~> 1.5"
gem "puma", "~> 6.5"
gem "redis", "~> 5.3"
gem "sprockets-rails"

gem "bootsnap", require: false

gem "hotwire-livereload", "~> 2.1"
gem "importmap-rails", "~> 2.0"
gem "sass-rails"
gem "stimulus-rails"
gem "turbo-rails"

gem "bcrypt", "~> 3.1.20"
gem "brakeman" # Look for security vulnerabilities
gem "bundler-audit" # Check dependencies for vulnerabilities
gem "cancancan"
gem "devise", "~> 5.0"
gem "devise-i18n"
gem "devise_invitable", "~> 2.0"
gem "lograge" # One-line-per-event format logs
gem "phony_rails"
gem "rails-i18n"

gem "vonage", "~> 7.28"

gem "avo", ">= 3.2.1"

gem "stackprof"
gem "sentry-ruby"
gem "sentry-rails"

group :development, :test do
  gem "debug", platforms: %i[mri mingw x64_mingw]
  gem "minitest"
  gem "minitest-mock"
  gem "ostruct"
  gem "factory_bot_rails"
  gem "faker"
  gem "minitest-reporters"
end

group :development do
  gem "annotaterb"
  gem "rack-mini-profiler"
  gem "rubocop-minitest", require: false
  gem "rubocop-rails", require: false
  # gem "web-console"
  gem "better_errors"
  gem "binding_of_caller"
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "selenium-webdriver"
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
