require "test_helper"

class ConversationalistTest < ActiveSupport::TestCase
  def test_contact_name_or_phone
    @contact = create(:contact)
    assert_equal(@contact.name_or_phone, @contact.name)

    @contact_2 = create(:contact, name: "")
    assert_equal(@contact_2.name_or_phone, @contact_2.phone)
  end
  
  def test_user_name_or_phone
    @user = create(:user)
    assert_equal(@user.name_or_phone, @user.name)
  end
end