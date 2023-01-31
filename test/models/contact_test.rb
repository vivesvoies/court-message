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

  def test_phone_number_validation_and_normalization
    @contact = build(:contact)

    # Vonage format
    @contact.phone = "33612345678"
    assert @contact.valid?
    assert_equal @contact.phone, "+33612345678"

    # e164 format
    @contact.phone = "+33612345678"
    assert @contact.valid?
    assert_equal @contact.phone, "+33612345678"

    # French hybrid
    @contact.phone = "+33(0)612345678"
    assert @contact.valid?
    assert_equal @contact.phone, "+33612345678"

    # French national
    @contact.phone = "0612345678"
    assert @contact.valid?
    assert_equal @contact.phone, "+33612345678"

    # French, space formatted
    @contact.phone = "06 12 34 56 78"
    assert @contact.valid?
    assert_equal @contact.phone, "+33612345678"

    # French, period formatted
    @contact.phone = "06.12.34.56.78"
    assert @contact.valid?
    assert_equal @contact.phone, "+33612345678"

    # Missing a digit
    @contact.phone = "061234567"
    assert @contact.invalid?

    # Neither cc nor 0
    @contact.phone = "16 12 34 56 78"
    assert @contact.invalid?

    # Both cc and 0. Perhaps should be handled by a before_validation callback?
    @contact.phone = "330612345678"
    assert @contact.invalid?
  end
end
