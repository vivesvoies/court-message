# == Schema Information
#
# Table name: contacts
#
#  id         :bigint           not null, primary key
#  email      :string
#  name       :string
#  phone      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class ContactTest < ActiveSupport::TestCase
  def test_destruction
    @contact = create(:contact)
    @conversation = @contact.create_conversation
    @message = create(:outbound_message, sender: @contact, conversation: @contact.conversation)

    @contact.destroy

    assert_nil Contact.find_by(id: @contact.id)
    assert_nil Conversation.find_by(id: @conversation.id)
    assert_nil Message.find_by(id: @message.id)
  end
end
