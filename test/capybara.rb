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
