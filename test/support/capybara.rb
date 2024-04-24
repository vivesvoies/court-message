if ENV["CI"]
  Capybara.register_driver :headless_chrome do |app|
    options = Selenium::WebDriver::Chrome::Options.new(
      args: %w[headless no-sandbox disable-gpu disable-dev-shm-usage],
      binary: '/usr/bin/google-chrome'
    )
  
    Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      options:
    )
  end
end
