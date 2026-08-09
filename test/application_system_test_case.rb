require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Devise::Test::IntegrationHelpers

  if ENV["HEADLESS_CHROME"] != "true"
    driven_by :selenium_chrome_in_container
  else
    driven_by :headless_selenium_chrome_in_container
  end

  # Bind every interface rather than the "web" alias: `docker compose run`
  # only applies service aliases with --use-aliases, and without it Capybara
  # fails to bind at all. The browser runs in another container, so it is
  # given this container's address on the compose network.
  Capybara.server_host = "0.0.0.0"
  Capybara.server_port = 3001
  Capybara.app_host = "http://#{Socket.ip_address_list.find { |a| a.ipv4? && !a.ipv4_loopback? }.ip_address}:#{Capybara.server_port}"
  Capybara.always_include_port = true

  # Turbo broadcasts go through broadcast_later, so the default :test queue
  # adapter records them without ever running them and nothing reaches the
  # browser. Paired with the async cable adapter in config/cable.yml.
  ActiveJob::Base.queue_adapter = :inline

  # System tests need committed data: Capybara serves the app from another
  # thread on its own connection, which cannot see an open transaction.
  def before_setup
    DatabaseCleaner.strategy = :truncation
    super
  end

  def after_teardown
    super
    DatabaseCleaner.strategy = :transaction
  end

  def resize_to_mobile
    resize_window_to(428, 926)
  end

  def resize_to_desktop
    resize_window_to(1080, 1024)
  end

  private

  def resize_window_to(w, h)
    Capybara.current_session.driver.browser.manage.window.resize_to(w, h)
  end
end
