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

  test "should not show and edit user when self" do
    user = create(:user)
    sign_in user
    get user_url(user)
    assert_response :forbidden
    get edit_user_url(user)
    assert_response :forbidden
  end

  test "should not show or edit user when not self" do
    user = create(:user)
    other_user = create(:user)
    sign_in user
    get user_url(other_user)
    assert_response :forbidden
    get edit_user_url(other_user)
    assert_response :forbidden
  end

  test "site admins should be able to show and edit any user" do
    user = create(:user, role: :site_admin)
    other_user = create(:user)
    sign_in user
    get user_url(other_user)
    assert_response :success
    get edit_user_url(other_user)
    assert_response :success
  end

  test "should not allow user to update via UserController" do
    user = create(:user)
    sign_in user
    patch user_url(user), params: { user: { name: "New name", email: "new@email.com", password: "password123", password_confirmation: "password123" } }
    assert_response :forbidden
  end

  test "should not allow user to update role" do
    user = create(:user)
    sign_in user
    patch user_url(user), params: { user: { role: :site_admin } }
    assert_response :forbidden
    assert_equal "user", user.reload.role
  end

  # FIXME: Check role modification in User Class
  # test "should allow site admin to update role" do
  #   user = create(:user, role: :site_admin)
  #   other_user = create(:user)
  #   sign_in user
  #   patch user_url(other_user), params: { user: { role: :team_admin } }
  #   assert_redirected_to user_url(other_user)
  #   assert_equal "team_admin", other_user.reload.role
  # end

  test "should allow site admin to delete user" do
    user = create(:user, role: :site_admin)
    other_user = create(:user)
    sign_in user
    delete user_url(other_user)
    assert_redirected_to users_url
    assert_equal 1, User.count
  end

  test "should not allow user to delete user" do
    user = create(:user)
    other_user = create(:user)
    sign_in user
    delete user_url(other_user)
    assert_response :forbidden
    assert_equal 2, User.count
  end

  test "admins cannot delete themselves" do
    user = create(:user, role: :site_admin)
    sign_in user
    delete user_url(user)
    assert_response :forbidden
    assert_equal 1, User.count
  end
end
