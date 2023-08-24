require "test_helper"
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "should redirect to sign in when signed out" do
    t = create(:team)
    get team_conversations_path(t)
    assert_redirected_to(user_session_path)
  end

  test "should redirect to team picker when signed in" do
    @user = create(:user)
    sign_in(@user)
    get root_url

    assert_redirected_to(teams_path)
  end
end
