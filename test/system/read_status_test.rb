require "application_system_test_case"
require_relative "../support/turbo_race_harness"

# Read and unread in the browser, replayed under each ordering of the network
# events that once sent a conversation marked unread straight back to read:
# the list's Turbo Stream update, the server's answer to the click, a new
# message. The harness holds and releases them on purpose (see
# test/support/turbo_race_harness.js), so these orderings run every time.
class ReadStatusTest < ApplicationSystemTestCase
  include TurboRaceHarness
  include ActionView::RecordIdentifier

  setup do
    @team = create(:team)
    @user = create(:user, teams: [ @team ])
    @colleague = create(:user, teams: [ @team ])
    @conversations = Array.new(4) { conversation_with_a_message }

    sign_in @user
    resize_to_desktop
  end

  # A request still running would reach the server once this test's data is
  # gone, and broadcast into the next test's page.
  teardown { wait_for_requests }

  test "a conversation marked unread from the list stays where it is, and can be marked read again" do
    visit_list
    order = list_ids
    conversation = @conversations.second

    hold_streams
    toggle_read(conversation)
    assert_shown(conversation, :unread)
    wait_for_held_streams
    release_streams
    settle

    assert(conversation.reload.unread?)
    assert_shown(conversation, :unread)
    assert_equal(order, list_ids, "marking it unread moved it")

    toggle_read(conversation)
    assert_shown(conversation, :read)
    wait_for_requests
    assert(conversation.reload.read?)
    assert_equal(%w[unread read], status_requests)
  end

  {
    "its list update arrives before the server's answer" => %i[streams responses],
    "the server's answer arrives before its list update" => %i[responses streams]
  }.each do |ordering, releases|
    test "the open conversation marked unread stays unread when #{ordering}" do
      conversation = @conversations.first
      visit_list
      open_conversation(conversation)

      hold_streams
      hold_responses(matching: "/status$")
      toggle_read(conversation)
      wait_for_held_responses
      wait_for_held_streams
      releases.each { |held| held == :streams ? release_streams : release_responses }
      settle

      assert_shown(conversation, :unread)
      assert(conversation.reload.unread?, "the browser marked it read again")
      assert_equal(%w[unread], status_requests)
    end
  end

  test "a colleague marking the open conversation unread does not bounce back to read" do
    conversation = @conversations.first
    visit_list
    open_conversation(conversation)

    hold_streams
    conversation.mark_as_unread!
    wait_for_held_streams
    release_streams
    settle

    assert_shown(conversation, :unread)
    assert(conversation.reload.unread?)
    assert_empty(status_requests)
  end

  test "a reply arriving in the open conversation marks it read, even just after it was marked unread" do
    conversation = @conversations.first
    visit_list
    open_conversation(conversation)
    toggle_read(conversation)
    wait_for_requests
    assert(conversation.reload.unread?)

    receive_reply(conversation)

    assert(eventually { conversation.reload.read? }, "the reply did not mark it read")
    assert_shown(conversation, :read)
    assert_equal(%w[unread read], status_requests)
  end

  test "a quick double toggle reaches the server in the order clicked" do
    conversation = @conversations.last
    visit_list

    hold_streams
    hold_responses(matching: "/status$")
    toggle_read(conversation)
    wait_for_held_responses
    toggle_read(conversation)
    assert_shown(conversation, :read)
    assert_equal(%w[unread], status_requests, "the second request left before the first was answered")

    release_responses
    wait_for_requests
    release_streams
    settle

    assert_equal(%w[unread read], status_requests)
    assert(conversation.reload.read?)
    assert_shown(conversation, :read)
  end

  # Not a fixed scenario: a random run of everything that can happen to the
  # list, checking after each step that the live list (order, read status, no
  # duplicates) is what a reload would show. A failure prints its seed; run it
  # again with READ_STATUS_SEED=<seed>.
  test "the live list always matches a reload" do
    seed = Integer(ENV.fetch("READ_STATUS_SEED") { Random.new_seed % 1_000_000 })
    random = Random.new(seed)
    history = []
    visit_list

    30.times do |step|
      event = EVENTS.sample(random:)
      conversation = @conversations.sample(random:)
      history << "#{event} #{dom_id(conversation)}"
      send(event, conversation)

      live = settle_list
      assert_equal(reloaded_list, live, <<~MESSAGE)
        The live list drifted from a reload at step #{step} (READ_STATUS_SEED=#{seed}).
        History: #{history.join(", ")}
        Status requests: #{page_requests(method: "PATCH").map { |request| "#{request["url"]} #{request["body"]}" }.join(", ")}
        Requests still running: #{page.evaluate_script("raceHarness.running()")}
        Stream messages: #{page_stream_log.last(12).join(" | ")}
      MESSAGE
    end
  end

  private

  EVENTS = %i[receive_reply colleague_writes colleague_marks_unread colleague_marks_read open_conversation toggle_read].freeze

  def conversation_with_a_message
    contact = create(:contact, team: @team)
    conversation = create(:conversation, contact:)
    create(:inbound_message, sender: contact, conversation:)
    conversation.reload
  end

  def visit_list
    visit team_conversations_url(@team)
    assert_selector "#conversations li.Conversation", count: @conversations.size
    install_race_harness
    wait_for_stream_subscriptions
  end

  def open_conversation(conversation)
    find("##{dom_id(conversation)} .Conversation__link").click
    assert_selector "##{dom_id(conversation)}.Conversation--active"
    assert_selector "#conversation_detail .ConversationDetail__title", text: conversation.title
    wait_for_stream_subscriptions
  end

  def toggle_read(conversation)
    find("##{dom_id(conversation)} .Conversation__read-toggle").click
  end

  # Same path as an SMS arriving through Vonage or a gateway.
  def receive_reply(conversation)
    InboundMessagesService.new({ from: conversation.contact.phone, text: "Une réponse" }).save
  end

  # Same path as MessagesController#create, from another browser.
  def colleague_writes(conversation)
    message = Message.create!(conversation_id: conversation.id, content: "Un message", sender: @colleague)
    OutboundMessagesService.new(message).submit!
  end

  def colleague_marks_unread(conversation) = Conversation.find(conversation.id).mark_as_unread!

  def colleague_marks_read(conversation) = Conversation.find(conversation.id).mark_as_read!

  def assert_shown(conversation, status)
    assert_selector "##{dom_id(conversation)}.Conversation--#{status}"
  end

  # Read in one script: Turbo renders stream actions on the next frame, and an
  # item replaced while Capybara walks the list reads as a stale node.
  def list_ids = live_list.map(&:first)

  def status_requests
    page_requests(method: "PATCH").map { |request| JSON.parse(request["body"])["status"] }
  end

  # Lets the page finish what the last event set off (a status request sent
  # from a list update, and that request's own list update).
  def settle
    wait_for_requests
    sleep 0.2
    wait_for_requests
  end

  # The list as the browser shows it, once it agrees with the server and stays
  # so with no request running: [[dom id, "read" | "unread"], ...].
  def settle_list(timeout: Capybara.default_max_wait_time)
    deadline = Time.current + timeout
    stable = 0
    loop do
      live = live_list
      stable = live == reloaded_list && page.evaluate_script("raceHarness.running()").zero? ? stable + 1 : 0
      return live if stable == 3 || Time.current > deadline

      sleep 0.1
    end
  end

  def live_list
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll("#conversations li.Conversation")]
        .map((item) => [item.id, item.classList.contains("Conversation--unread") ? "unread" : "read"])
    JS
  end

  # Uncached: the test runs inside the Rails executor, whose query cache would
  # keep answering the first result while the app server changes the rows.
  def reloaded_list
    Conversation.uncached do
      Conversation.for_team(@team).map { |conversation| [ dom_id(conversation), conversation.status ] }
    end
  end

  def eventually(timeout: Capybara.default_max_wait_time)
    deadline = Time.current + timeout
    until (result = yield)
      return false if Time.current > deadline

      sleep 0.1
    end
    result
  end
end
