# == Schema Information
#
# Table name: messages
#
#  id              :bigint           not null, primary key
#  content         :string
#  outbound_uuid   :uuid
#  provider_info   :jsonb
#  sender_type     :string           not null
#  status          :enum             default("unsent"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#  sender_id       :bigint           not null
#
# Indexes
#
#  index_messages_on_conversation_id  (conversation_id)
#  index_messages_on_outbound_uuid    (outbound_uuid)
#  index_messages_on_sender           (sender_type,sender_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#
require "test_helper"

class MessageTest
  class MessageStatus < ActiveSupport::TestCase
    def test_default_status
      m = Message.new
      assert(m.unsent_status?)
    end

    def test_direction
      message_from_user = create(:outbound_message)
      message_from_contact = create(:inbound_message)

      assert_equal(message_from_user.direction, :outbound)
      assert_equal(message_from_contact.direction, :inbound)
    end

    def test_valid_statuses
      valid_statuses = %w[inbound unsent submitted delivered rejected undeliverable expired failed deleted]
      message = Message.new(content: "Test content", conversation: create(:conversation), sender: create(:contact))

      valid_statuses.each do |status|
        message.status = status
        assert message.valid?
      end
    end

    def test_invalid_status
      message = Message.new(content: "Test content", conversation: create(:conversation), sender: create(:contact))
      assert_raises ArgumentError do
        message.status = "invalid_status"
      end
    end
  end

  class MessageValidations < ActiveSupport::TestCase
    def test_content
      m = create(:outbound_message)
      assert(m.valid?)

      m.content = "       " # tabs, spaces, nbsps
      assert_not(m.valid?)
    end

    def test_content_size
      content = "This is a long message " * 50
      m = create(:outbound_message, content: content)

      assert(m.valid?)
      assert(m.content == content)
    end

    def test_nullify_last_message
      message = create(:outbound_message)
      conversation = message.conversation

      conversation.update(last_message_id: message.id)
      message.destroy

      assert_nil conversation.reload.last_message_id
    end
  end
end
