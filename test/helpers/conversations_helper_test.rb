require "test_helper"

class ConversationsHelperTest < ActiveSupport::TestCase
  include ConversationsHelper

  def test_last_message_extract_for
    empty_convo = create(:conversation)
    convo_with_message = create(:conversation)
    message = create(:inbound_message, content: "0123456789" * 15)
    convo_with_message.messages << message

    assert_equal(last_message_extract_for(empty_convo), "")
    assert_equal(last_message_extract_for(convo_with_message), "0123456789" * 11 + "...")
  end

  def test_last_message_class_for
    empty_convo = create(:conversation)

    last_outbound = create(:conversation)
    outbound_message = create(:outbound_message)
    last_outbound.messages << outbound_message

    last_inbound = create(:conversation)
    inbound_message = create(:inbound_message)
    last_inbound.messages << inbound_message

    assert_equal(last_message_class_for(empty_convo), "Conversation__sub--empty")
    assert_equal(last_message_class_for(last_outbound), "Conversation__sub--outbound")
    assert_equal(last_message_class_for(last_inbound), "Conversation__sub--inbound")
  end
end
