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
#  team_id    :bigint           default(2), not null
#
# Indexes
#
#  index_contacts_on_phone              (phone)
#  index_contacts_on_team_id            (team_id)
#  index_contacts_on_team_id_and_phone  (team_id,phone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#
require "test_helper"

class ContactTest < ActiveSupport::TestCase
  def test_destruction
    @contact = create(:contact)
    @conversation = @contact.create_conversation
    @message = create(:outbound_message, sender: @contact, conversation: @contact.conversation)

    @contact.destroy

    assert_raises(ActiveRecord::RecordNotFound) { Contact.find(@contact.id) }
    assert_raises(ActiveRecord::RecordNotFound) { Conversation.find(@conversation.id) }
    assert_raises(ActiveRecord::RecordNotFound) { Message.find(@message.id) }
  end

  def test_email_validations
    @contact = create(:contact)

    assert_raises(ActiveRecord::RecordInvalid) {
      create(:contact, email: @contact.email, team: @contact.team)
    }

    @contact_same_email_diff_team = create(:contact, email: @contact.email)
    assert(@contact_same_email_diff_team.valid?)

    @contact_no_email = create(:contact, email: nil)
    assert(@contact_no_email.valid?)

    @contact_no_email_2 = create(:contact, email: nil)
    assert(@contact_no_email_2.valid?)

    @contact_blank_email = create(:contact, email: "")
    assert(@contact_blank_email.valid?)

    @contact_blank_email_2 = create(:contact, email: "")
    assert(@contact_blank_email_2.valid?)
  end

  def test_phone_validations
    @contact = create(:contact)
    assert(@contact.valid?)

    assert_raises(ActiveRecord::RecordInvalid) {
      create(:contact, phone: @contact.phone, team: @contact.team)
    }

    @contact_same_phone_diff_team = create(:contact, phone: @contact.phone)
    assert(@contact_same_phone_diff_team.valid?)

    assert_raises(ActiveRecord::RecordInvalid) {
      create(:contact, phone: " ")
    }

    assert_raises(ActiveRecord::RecordInvalid) {
      create(:contact, phone: nil)
    }
  end

  def test_phone_number_plausibility_and_normalization
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

  def test_having_same_contact_multiple_teams
    contact = create(:contact)
    team = contact.team
    other_team = create(:team)

    other_contact = build(:contact, email: contact.email, name: contact.name, phone: contact.phone, team: other_team)
    assert other_contact.valid?
    assert_nothing_raised { other_contact.save }
  end
end
