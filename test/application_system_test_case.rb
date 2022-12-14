require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  if ENV["HEADLESS_CHROME"] != "true"
    driven_by :selenium_chrome_in_container
  else
    driven_by :headless_selenium_chrome_in_container
  end
  
  Capybara.server_host = "0.0.0.0"
  Capybara.server_port = 4000
  Capybara.app_host = "http://web:4000"
end
