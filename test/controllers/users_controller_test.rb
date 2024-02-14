require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = create(:team)
    @other_team = create(:team)
    @user = create(:user, role: :user, teams: [ @team ])
    @other_user = create(:user, role: :user, teams: [ @team ])
    @team_admin = create(:user, role: :team_admin, teams: [ @team ])
    @site_admin = create(:user, role: :site_admin, teams: [ @team ])
    @user = @team.users.first
    @team_admin = @team.users.first
    @site_admin = @team.users.first
  end

  test "normal users should be able to access index" do
    sign_in @user
    get team_users_url(@team)
    assert_response :success
    sign_out @user
  end

  test "team admins should be able to access index" do
    sign_in @team_admin
    get team_users_url(@team)
    assert_response :success
    sign_out @team_admin
  end

  test "site admins should be able to access index of all teams" do
    sign_in @site_admin
    get team_users_url(@team)
    assert_response :success
    get team_users_url(@other_team, @site_admin)
    assert_response :success
    sign_out @site_admin
  end

  test "users should not be able to access index of another team" do
    sign_in @user
    get team_users_url(@other_team, @user)
    assert_response :forbidden
    sign_out @user
  end

  test "team admins should not be able to access index of another team" do
    sign_in @team_admin
    get team_users_url(@other_team, @team_admin)
    assert_response :forbidden
    sign_out @team_admin
  end

  test "should be able edit user when self" do
    sign_in @user
    get edit_team_user_url(@team, @user)
    assert_response :success
    sign_out @user
  end

  test "team admins should be able to edit any user" do
    sign_in @team_admin
    get edit_team_user_url(@team, @other_user)
    assert_response :success
    sign_out @team_admin
  end

  test "site admins should be able to edit any user" do
    sign_in @site_admin
    get edit_team_user_url(@team, @other_user)
    assert_response :success
    sign_out @site_admin
  end

  test "should not edit user when not self" do
    sign_in @user
    get edit_team_user_url(@team, @other_user)
    assert_response :forbidden
    sign_out @user
  end

  test "users should not be able to create user" do
    sign_in @user
    get new_team_user_url(@team)
    assert_response :forbidden
  end

  test "team admins should be able to create user" do
    sign_in @team_admin
    get new_team_user_url(@team)
    assert_response :success
  end

  test "site admins should be able to create user" do
    sign_in @site_admin
    get new_team_user_url(@team)
    assert_response :success
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

  # TODO: uncomment when implementing UsersController
  # test "should not allow user to update via UserController" do
  #   sign_in @user
  #   patch user_url(user), params: { user: { name: "New name", email: "new@email.com", password: "password123", password_confirmation: "password123" } }
  #   assert_response :forbidden
  # end

  # test "should not allow user to update role" do
  #   sign_in @user
  #   patch user_url(user), params: { user: { role: :site_admin } }
  #   assert_response :forbidden
  #   assert_equal "user", user.reload.role
  # end

  # test "should allow site admin to update role" do
  #   sign_in @site_admin
  #   patch user_url(other_user), params: { user: { role: :team_admin } }
  #   assert_redirected_to user_url(other_user)
  #   assert_equal "team_admin", other_user.reload.role
  # end

  # test "should allow site admin to delete user" do
  #   sign_in @site_admin
  #   delete user_url(other_user)
  #   assert_redirected_to users_url
  #   assert_equal 1, User.count
  # end

  # test "should not allow user to delete user" do
  #   sign_in @user
  #   delete user_url(other_user)
  #   assert_response :forbidden
  #   assert_equal 2, User.count
  # end

  # test "admins cannot delete themselves" do
  #   sign_in @user
  #   delete user_url(user)
  #   assert_response :forbidden
  #   assert_equal 1, User.count
  # end
end
