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
  test "the truth" do
    convo = conversations(:one)
    msgs = convo.messages
    
    assert(msgs.count == 2)
  end
end
