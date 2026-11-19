# Capybara 3.40 resets a Chrome session with Storage.clearDataForOrigin on the
# origin "*", which recent Chrome rejects ("* is not a valid URL"): every system
# test then errors in its teardown. Clear cookies everywhere and storage for the
# app's own origin instead.
require "capybara/selenium/driver"
require "capybara/selenium/driver_specializations/chrome_driver"

module ChromeStorageResetPerOrigin
  def execute_cdp(cmd, params = {})
    return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Network.clearBrowserCookies")
    origin = Capybara.app_host || Capybara.current_session.server&.base_url
    super(cmd, params.merge(origin:)) if origin
  end
end
Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeStorageResetPerOrigin)

Capybara.register_driver :selenium_chrome_in_container do |app|
  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://selenium-hub:4444/wd/hub",
    capabilities: :chrome
  )
end

Capybara.register_driver :headless_selenium_chrome_in_container do |app|
  chrome_options = Selenium::WebDriver::Chrome::Options.new
  chrome_options.add_argument("--headless")
  chrome_options.add_argument("--disable-gpu")

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://selenium-hub:4444/wd/hub",
    capabilities: chrome_options
  )
end
