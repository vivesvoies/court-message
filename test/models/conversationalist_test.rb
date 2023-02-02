require "test_helper"

class ConversationalistTest < ActiveSupport::TestCase
  def test_contact_to_s_gives_name_first
    @contact = create(:contact)
    assert_equal(@contact.to_s, @contact.name)
  end

  def test_contact_to_s_gives_formatted_phone
    @contact_2 = create(:contact, name: "", phone: "33612345678")
    assert_equal("06 12 34 56 78", @contact_2.to_s)
  end

  def test_user_to_s_gives_name
    @user = create(:user)
    assert_equal(@user.to_s, @user.name)
  end

  def test_user_to_s_gives_email
    # Frankly, this is a bad feature. Name should be enforced.
    @user_2 = create(:user, name: nil)
    assert_equal(@user_2.to_s, @user_2.email)
  end

  def test_contact_no_name_no_phone_no_mail
    # Frankly, this is a dreadful feature. Sanitize your db!
    @contact = create(:contact)
    @contact.name = nil
    @contact.phone = nil
    @contact.email = nil
    assert_equal("#<Contact id=#{@contact.id}>", @contact.to_s)
  end
end
