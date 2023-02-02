require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contact = create(:contact)
    @temp = build(:contact)
    @user = create(:user)

    sign_in(@user)
  end

  test "should not get index" do
    assert_raises(ActionController::RoutingError) {
      get contacts_url
    }
  end

  test "should get new" do
    get new_contact_url
    assert_response :success
  end

  test "should create contact and no conversation" do
    assert_difference -> { Contact.count } => 1, -> { Conversation.count } => 0 do
      post contacts_url, params: { contact: { name: @temp.name, email: @temp.email, phone: @temp.phone } }
    end

    assert_redirected_to contact_url(Contact.last)
  end

  test "should create conversation when flag is set" do
    assert_difference(["Contact.count", "Conversation.count"]) do
      post contacts_url,
           params: { contact: { name: @temp.name, email: @temp.email, phone: @temp.phone }, create_conversation: true }
    end

    assert_redirected_to contact_url(Contact.last)
  end

  test "should show contact" do
    get contact_url(@contact)
    assert_response :success
  end

  test "should get edit" do
    get edit_contact_url(@contact)
    assert_response :success
  end

  test "should update contact" do
    patch contact_url(@contact), params: { contact: { name: "Other name" } }
    assert_redirected_to contact_url(@contact)
  end

  test "should destroy contact" do
    assert_difference("Contact.count", -1) do
      delete contact_url(@contact)
    end

    assert_redirected_to root_url
  end
end
