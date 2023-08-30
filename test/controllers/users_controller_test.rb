require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "normal users should not be able to access index" do
    user = create(:user)
    sign_in user
    get users_url
    assert_response :forbidden
  end

  test "team admins should not be able to access index" do
    user = create(:user, role: :team_admin)
    sign_in user
    get users_url
    assert_response :forbidden
  end

  test "site admins should be able to access index" do
    user = create(:user, role: :site_admin)
    sign_in user
    get users_url
    assert_response :success
  end
end
