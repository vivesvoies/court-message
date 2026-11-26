require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Devise::Test::IntegrationHelpers

  if ENV["CI"]
    # CI runs the browser alongside the tests, so Selenium Manager can resolve
    # the driver itself and the default localhost app host applies.
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
  else
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
  end

  Capybara.always_include_port = true

  # Turbo broadcasts go through broadcast_later, so the default :test queue
  # adapter records them without ever running them and nothing reaches the
  # browser. Paired with the async cable adapter in config/cable.yml.
  ActiveJob::Base.queue_adapter = :inline

  # System tests need committed data: Capybara serves the app from another
  # thread on its own connection, which cannot see an open transaction.
  #
  # Ids keep counting across tests: stream names carry them (the team's list
  # is "team_conversations_list_1" in every test otherwise), and a broadcast
  # still in flight from the previous test would land in this test's page.
  def before_setup
    DatabaseCleaner.strategy = :truncation, { reset_ids: false }
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

  # Clicks a link that loads a Turbo frame, then waits until the frame shows
  # the response. A frame can already hold what the response brings back (the
  # conversations page opens on the contact search, and "Écrire un message"
  # loads it again), so without the wait the test may type into the old
  # content, which the response then replaces.
  def click_on_and_wait_for_frame(locator, frame:)
    page.execute_script(<<~JS, frame)
      const frame = document.getElementById(arguments[0])
      frame.removeAttribute("data-test-loaded")
      frame.addEventListener("turbo:frame-load", () => frame.setAttribute("data-test-loaded", ""), { once: true })
    JS
    click_on locator
    assert_selector "turbo-frame##{frame}[data-test-loaded]"
  end

  private

  def resize_window_to(w, h)
    Capybara.current_session.driver.browser.manage.window.resize_to(w, h)
  end
end
