require "test_helper"
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "should redirect to sign in when signed out" do
    get root_url
    assert_redirected_to(user_session_path)

    @user = create(:user)
    sign_in(@user)
    get root_url
    assert_response :success
  end
end
