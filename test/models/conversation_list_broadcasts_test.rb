require "test_helper"

# What the conversation lists receive, over Turbo Streams, for each thing that
# can happen to a conversation. The lists are the team's ("Toutes les
# conversations") and each agent's ("Mes conversations").
#
# The contract:
# - a new message, in or out, moves the conversation to the top of every list
#   (remove, then prepend, on the same stream so they cannot swap);
# - anything else (read, unread, a delivery receipt touching the conversation)
#   refreshes it in place: it must not move, or a manual "unread" would jump to
#   the top and the open list would disagree with a reload.
class ConversationListBroadcastsTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  MOVE = [ "remove", "prepend" ].freeze

  setup do
    @team = create(:team)
    @agent = create(:user, teams: [ @team ])
    @contact = create(:contact, team: @team)
    @conversation = create(:conversation, contact: @contact)
    @conversation.agents << @agent
  end

  test "an inbound message moves the conversation to the top, unread" do
    received = list_broadcasts { receive_sms }

    assert_equal(MOVE, actions(received[:team]))
    assert_equal(MOVE, actions(received[:agent]))
    assert_empty(received[:item])
    assert_rendered_as(:unread, received[:team].last)
  end

  test "an outbound message moves the conversation to the top of every list, its author's included" do
    author = create(:user, teams: [ @team ])

    received = list_broadcasts(author) { send_sms(author) }

    # Then the send itself saves the message again, which only refreshes.
    assert_moved_to_top(received[:team])
    assert_moved_to_top(received[:agent])
    assert_moved_to_top(received[author], "the author just became an agent of the conversation")
    assert_rendered_as(:read, received[:team].second)
  end

  test "marking a conversation read refreshes it in place" do
    @conversation.update!(read: false)

    received = list_broadcasts { @conversation.mark_as_read! }

    assert_refreshed_in_place(received)
    assert_rendered_as(:read, received[:item].last)
  end

  test "marking a conversation unread refreshes it in place, without moving it to the top" do
    received = list_broadcasts { @conversation.mark_as_unread! }

    assert_refreshed_in_place(received)
    assert_rendered_as(:unread, received[:item].last)
  end

  test "a delivery receipt on an unread conversation does not move it" do
    message = send_sms(@agent)
    receive_sms
    assert(@conversation.reload.unread?)

    # Loaded afresh, like the status webhook does.
    received = list_broadcasts { Message.find(message.id).update!(status: :delivered) }

    assert_refreshed_in_place(received)
  end

  test "a rolled back message does not leave a pending move behind" do
    received = list_broadcasts do
      ActiveRecord::Base.transaction do
        create(:inbound_message, sender: @contact, conversation: @conversation)
        raise ActiveRecord::Rollback
      end
    end
    assert(received.values.all?(&:empty?), "nothing was committed, nothing is broadcast")

    # As in the next request, which gets a fresh row in the same object.
    received = list_broadcasts { @conversation.reload.mark_as_unread! }

    assert_refreshed_in_place(received)
  end

  test "items carry their last message, so the browser can tell a new message from a status change" do
    received = list_broadcasts { receive_sms }

    item = received[:team].last.at_css("li.Conversation")
    assert_equal(@conversation.reload.last_message_id.to_s, item["data-last-message-id"])
  end

  private

  # Runs the block and returns, per list stream, the Turbo Stream elements it
  # received meanwhile.
  def list_broadcasts(*extra_agents)
    streams = {
      team: "team_conversations_list_#{@team.id}",
      item: "conversation_list_item_#{@conversation.id}",
      agent: "user_conversations_list_#{@agent.id}"
    }
    extra_agents.each { |user| streams[user] = "user_conversations_list_#{user.id}" }

    seen = streams.transform_values { |stream| broadcasts(stream).size }
    yield
    streams.to_h do |key, stream|
      [ key, broadcasts(stream).drop(seen[key]).flat_map { |payload| parse(payload) } ]
    end
  end

  def actions(stream_elements) = stream_elements.map { |element| element["action"] }

  def parse(payload)
    Nokogiri::HTML5.parse(ActiveSupport::JSON.decode(payload)).at("body").element_children
  end

  def assert_moved_to_top(stream_elements, message = nil)
    moves, refreshes = actions(stream_elements).partition.with_index { |_, index| index < 2 }
    assert_equal(MOVE, moves, message)
    assert_equal([ "replace" ] * refreshes.size, refreshes, message)
  end

  def assert_refreshed_in_place(received)
    [ :team, :item, :agent ].each do |list|
      assert_not_includes(actions(received[list]), "prepend", "#{list} list: the conversation moved")
      assert_not_includes(actions(received[list]), "remove", "#{list} list: the conversation was removed")
    end
    assert_includes(actions(received[:item] + received[:team]), "replace", "the open lists were not refreshed")
    assert_includes(actions(received[:agent]), "replace", "the agent's list was not refreshed")
  end

  def assert_rendered_as(status, stream_element)
    item = stream_element.at_css("li.Conversation")
    assert(item, "no conversation rendered in #{stream_element.to_html.truncate(200)}")
    assert_includes(item["class"].split, "Conversation--#{status}")
  end

  # Same path as an SMS arriving through Vonage or a gateway.
  def receive_sms
    InboundMessagesService.new({ from: @contact.phone, text: "Une réponse" }).save
  end

  # Same path as MessagesController#create.
  def send_sms(author)
    message = Message.new(conversation_id: @conversation.id, content: "Un message", sender: author)
    message.save!
    OutboundMessagesService.new(message).submit!
    message
  end
end
