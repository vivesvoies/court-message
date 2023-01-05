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
  end
end
