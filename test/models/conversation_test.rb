# == Schema Information
#
# Table name: conversations
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  contact_id :bigint           not null
#
# Indexes
#
#  index_conversations_on_contact_id  (contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#
require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  def test_title_shows_name_if_present
    @contact = create(:contact)
    @conversation = @contact.create_conversation

    assert_equal(@conversation.title, @contact.name)
  end

  def test_title_shows_phone_when_no_name
    @contact = create(:contact, name: "")
    @conversation = @contact.create_conversation

    assert_equal(@conversation.title, @contact.phone)
  end
end
