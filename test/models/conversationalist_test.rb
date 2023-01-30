require "test_helper"

class ConversationalistTest < ActiveSupport::TestCase
  def test_contact_to_s
    @contact = create(:contact)
    assert_equal(@contact.to_s, @contact.name)

    @contact_2 = create(:contact, name: "")
    assert_equal(@contact_2.to_s, @contact_2.phone)
  end

  def test_user_to_s
    @user = create(:user)
    assert_equal(@user.to_s, @user.name)

    # Frankly, this is a bad feature. Name should be enforced.
    @user_2 = create(:user, name: nil)
    assert_equal(@user_2.to_s, @user_2.email)
  end
end
