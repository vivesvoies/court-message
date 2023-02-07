require "test_helper"
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "should redirect to sign in when signed out" do
    get conversations_url
    assert_redirected_to(user_session_path)
  end

  test "should redirect to conversations path when signed in" do
    @user = create(:user)
    sign_in(@user)
    get root_url
    assert_redirected_to(conversations_path)

    get conversations_url
    assert_response :success
  end
end
