require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Devise::Test::IntegrationHelpers

  if ENV["HEADLESS_CHROME"] != "true"
    driven_by :selenium_chrome_in_container
  else
    driven_by :headless_selenium_chrome_in_container
  end

  Capybara.server_host = "0.0.0.0"
  Capybara.server_port = 4000
  Capybara.app_host = "http://web:4000"

  def resize_to_mobile
    resize_window_to(428, 926)
  end

  def resize_to_desktop
    resize_window_to(1080, 1024)
  end

  private

  def resize_window_to w, h
    Capybara.current_session.driver.browser.manage.window.resize_to(w, h)
  end
end
