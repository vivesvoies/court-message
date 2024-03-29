require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = create(:team)
    @other_team = create(:team)
    @user = create(:user, role: :user, teams: [ @team ])
    @other_user = create(:user, role: :user, teams: [ @other_team ])
    @other_team_user = create(:user, role: :user, teams: [ @team ])
    @team_admin = create(:user, role: :team_admin, teams: [ @team ])
    @site_admin = create(:user, role: :site_admin, teams: [ @team ])
  end

  test "should get show" do
    sign_in @user
    get team_user_url(@team, @user)
    assert_response :success
  end

  test "normal users should be able to access their team" do
    sign_in @user
    get team_url(@team)
    assert_response :success
    sign_out @user
  end

  test "team admins should be able to access their team" do
    sign_in @team_admin
    get team_url(@team, @user)
    assert_response :success
    sign_out @team_admin
  end

  test "site admins should be able to access all teams" do
    sign_in @site_admin
    get team_url(@team, @user)
    assert_response :success

    get team_url(@other_team, @site_admin)
    assert_response :success
    sign_out @site_admin
  end

  test "users should not be able to access to an another team" do
    sign_in @user
    get team_url(@other_team, @user)
    assert_response :forbidden
    sign_out @user
  end

  test "team admins should not be able to access to an another team" do
    sign_in @team_admin
    get team_url(@other_team, @team_admin)
    assert_response :forbidden
    sign_out @team_admin
  end

  test "should update user" do
    sign_in @team_admin
    patch team_user_url(@team, @user), params: { user: { id: @user.id, name: "Update Name" } }

    assert_redirected_to team_url(@team)
    assert_equal I18n.t("users.update.user_updated"), flash[:notice]

    @user.reload
    assert_equal(@user.name, "Update Name")
  end

  test "should be able edit user when self" do
    sign_in @user
    get edit_team_user_url(@team, @user)
    assert_response :success
    sign_out @user
  end

  test "team admins should be able to edit user in their team" do
    sign_in @team_admin
    get edit_team_user_url(@team, @user)
    assert_response :success

    get edit_team_user_url(@team, @other_user)
    assert_response :forbidden
    sign_out @team_admin
  end

  test "site admins should be able to edit any user" do
    sign_in @site_admin
    get edit_team_user_url(@other_team, @other_user)
    assert_response :success

    get edit_team_user_url(@team, @team_admin)
    assert_response :success
    sign_out @site_admin
  end

  test "users should not edit user when not self" do
    sign_in @user
    get edit_team_user_url(@team, @other_user)
    assert_response :forbidden
    sign_out @user
  end

  test "should not allow user to update via UserController" do
    sign_in @user
    other_user = create(:user, role: :user, teams: [ @team ])
    patch team_user_url(@team, other_user), params: { user: { name: "New name", email: "new@email.com", password: "password123", password_confirmation: "password123" } }
    assert_response :forbidden
  end

  test "should not allow user to update role" do
    sign_in @user
    patch team_user_url(@team, @user), params: { user: { role: :site_admin } }
    assert_redirected_to team_url(@team)
    assert_equal "user", @user.reload.role

    patch team_user_url(@team, @user), params: { user: { role: :team_admin } }
    assert_redirected_to team_url(@team)
    assert_equal "user", @user.reload.role
  end

  test "should not allow site admin to update role" do
    sign_in @site_admin
    patch team_user_url(@team, @other_team_user), params: { user: { role: :team_admin } }
    assert_redirected_to team_url(@team)
    assert_equal "user", @other_team_user.reload.role
  end
end
