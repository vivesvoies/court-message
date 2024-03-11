require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = create(:team)
    @other_team = create(:team)
    @admin = create(:user, role: :team_admin, teams: [ @team ])
    sign_in @admin
  end

  test "should not get index" do
    assert_raises(ActionController::RoutingError) {
      get memberships_url
    }
  end

  test "should get new" do
    get new_membership_url(team_id: @team.id)
    assert_response :success
  end

  test "should not get new without team" do
    assert_raises(ActiveRecord::RecordNotFound) {
      get new_membership_url
    }
  end

  test "should not get new without proper team" do
    get new_membership_url(team_id: @other_team.id)
    assert_response :forbidden
  end

  test "should create membership" do
    user = create(:user)
    assert_difference("Membership.count") do
      post memberships_url, params: { membership: { user_id: user.id, team_id: @team.id } }
    end

    assert_redirected_to team_path(@team)
  end

  test "should not create membership in another team" do
    user = create(:user)
    assert_no_difference("Membership.count") do
      post memberships_url, params: { membership: { user_id: user.id, team_id: @other_team.id } }
    end

    assert_response :forbidden
  end

  test "should destroy membership" do
    membership = create(:membership, team: @team)
    assert_difference("Membership.count", -1) do
      delete membership_url(membership)
    end

    assert_redirected_to team_path(@team)
  end

  test "should destroy user if is not in any team" do
    user = create(:user)
    user.update(team_ids: [])
    membership = create(:membership, team: @team, user: user)

    assert_difference("User.count", -1) do
      delete membership_url(membership)
    end

    assert_redirected_to team_path(@team)
  end

  test "should destroy membership if invitation is revoke and user does belong to a team" do
    user = create(:user)
    membership = create(:membership, team: @team, user: user)

    assert_difference("Membership.count", -1) do
      assert_difference("User.count", 0) do
        delete membership_url(membership)
      end
    end
  end

  test "should not destroy membership in another team" do
    membership = create(:membership, team: @other_team)
    assert_no_difference("Membership.count") do
      delete membership_url(membership)
    end

    assert_response :forbidden
  end

  test "site admin should create membership in another team" do
    site_admin = create(:user, role: :site_admin)
    user = create(:user)
    sign_in site_admin
    assert_difference("Membership.count") do
      post memberships_url, params: { membership: { user_id: user.id, team_id: @other_team.id } }
    end
  end
end
