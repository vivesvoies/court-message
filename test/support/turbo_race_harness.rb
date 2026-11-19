# Replays network races on purpose in system tests: hold Turbo Stream messages
# and fetch() responses, then release them in the order the test chooses. See
# turbo_race_harness.js. Install it after each full page load (visit); Turbo
# frame navigations keep it.
module TurboRaceHarness
  SCRIPT = File.read(File.expand_path("turbo_race_harness.js", __dir__))

  def install_race_harness
    page.execute_script(SCRIPT)
  end

  # Broadcasts sent before a stream source is subscribed are lost for good.
  def wait_for_stream_subscriptions
    assert_no_selector "turbo-cable-stream-source:not([connected])", visible: :all
  end

  def hold_streams = page.execute_script("raceHarness.holdStreams()")

  def release_streams = page.execute_script("raceHarness.releaseStreams()")

  def hold_responses(matching:)
    page.execute_script("raceHarness.holdResponses(arguments[0])", matching)
  end

  def release_responses = page.execute_script("raceHarness.releaseResponses()")

  def wait_for_held_streams(count = 1)
    wait_until("#{count} held stream message(s)") { page.evaluate_script("raceHarness.heldStreams()") >= count }
  end

  def wait_for_held_responses(count = 1)
    wait_until("#{count} held response(s)") { page.evaluate_script("raceHarness.heldResponses()") >= count }
  end

  # Waits until the page's fetch() calls have all been answered (at once when
  # the harness is not installed).
  def wait_for_requests
    wait_until("the page's requests to finish") do
      page.evaluate_script("window.raceHarness ? raceHarness.running() : 0").zero?
    end
  end

  # The page's fetch() calls so far: [{ "method" =>, "url" =>, "body" => }].
  def page_requests(method: nil)
    requests = page.evaluate_script("raceHarness.requests()")
    method ? requests.select { |request| request["method"] == method } : requests
  end

  # Every Turbo Stream message the page received, held or not, summarized as
  # "action target classes" (e.g. "prepend conversations Conversation Conversation--unread").
  def page_stream_log = page.evaluate_script("raceHarness.streamLog()")

  def wait_until(what, timeout: Capybara.default_max_wait_time)
    deadline = Time.current + timeout
    until yield
      flunk("Timed out waiting for #{what}") if Time.current > deadline
      sleep 0.05
    end
  end
end
