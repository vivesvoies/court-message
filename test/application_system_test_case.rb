require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Devise::Test::IntegrationHelpers

  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  def resize_to_mobile
    resize_window_to(428, 926)
  end

  def resize_to_desktop
    resize_window_to(1400, 1400)
  end

  private

  def resize_window_to(w, h)
    Capybara.current_session.driver.browser.manage.window.resize_to(w, h)
  end
end
