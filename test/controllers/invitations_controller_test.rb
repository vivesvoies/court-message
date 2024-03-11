require "test_helper"


class InvitationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @team = create(:team)
    @user = create(:user, teams: [ @team ])
    @other_user = create(:user)
  end

  test "should create a new user when invited" do
    sign_in @user

    assert_difference("User.count") do
      post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: "john@example.com" } }
    end

    assert_redirected_to team_url(@team)
  end

  test "should create a new membership when invited" do
    sign_in @user

    assert_difference("Membership.count") do
      post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: "john@example.com" } }
    end

    assert_redirected_to team_url(@team)
  end

  test "should resend invitation if user is already in the team and not confirmed" do
    sign_in @user

    assert_difference("User.count") do
      post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: "john@example.com" } }
    end

    user = User.find_by(email: "john@example.com")
    sent_at = user.invitation_sent_at

    assert_no_difference("User.count") do
      post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: "john@example.com" } }
    end
    user.reload
    assert_not_equal(sent_at, user.invitation_sent_at)

    assert_redirected_to team_url(@team)
  end

  test "should not send invitation if user is already in the team and confirm" do
    sign_in @user
    @user.update(confirmed_at: DateTime.now, invitation_sent_at: nil)

    post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: @user.email } }
    @user.reload
    assert_nil(@user.invitation_sent_at)

    assert_redirected_to team_url(@team)
    assert_equal I18n.t("devise.invitations.user_already_in_the_team"), flash[:notice]
  end

  test "should not create a new user if user is already in the team and confirm" do
    sign_in @user
    @user.update(confirmed_at: DateTime.now)

    assert_no_difference("User.count") do
      post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: @user.email } }
    end

    assert_redirected_to team_url(@team)
    assert_equal I18n.t("devise.invitations.user_already_in_the_team"), flash[:notice]
  end

  test "should not create an invitation if user is already in a team and confirm" do
    sign_in @user
    @user.update(confirmed_at: DateTime.now, invitation_token: nil)

    post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: @other_user.email } }
    @user.reload
    assert_nil(@user.invitation_token)

    assert_redirected_to team_url(@team)
  end

  test "should not create a new user if user is already in a team" do
    sign_in @user

    assert_no_difference("User.count") do
      post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: @other_user.email } }
    end

    assert_redirected_to team_url(@team)
  end

  test "should create a membership if user is already in a team" do
    sign_in @user

    assert_difference("Membership.count") do
      post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: @other_user.email } }
    end

    assert_redirected_to team_url(@team)
  end

  test "should redirect to sign in page if not signed in" do
    sign_out :user

    post user_team_invitation_path(@team), params: { user: { name: "John Doe", email: "john@example.com" } }

    assert_redirected_to new_user_session_path
  end
end
