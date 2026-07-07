require "test_helper"

class AbilityTest < ActiveSupport::TestCase
  # Per-team roles (#130): a user can be admin of team A and a plain member of
  # team B. Team-admin powers must apply ONLY to the teams the user administers.
  setup do
    @team_a = create(:team)
    @team_b = create(:team)
    @user = create(:user, teams: [])
    create(:membership, :admin, user: @user, team: @team_a)
    create(:membership, user: @user, team: @team_b) # plain member
    @user.reload
    @ability = Ability.new(@user)
  end

  test "admin of team A can manage memberships of team A" do
    membership_a = create(:membership, team: @team_a)
    assert @ability.can?(:manage, membership_a)
    assert @ability.can?(:create, membership_a)
    assert @ability.can?(:destroy, membership_a)
  end

  test "member of team B cannot manage memberships of team B" do
    membership_b = create(:membership, team: @team_b)
    assert @ability.cannot?(:manage, membership_b)
    assert @ability.cannot?(:create, membership_b)
    assert @ability.cannot?(:destroy, membership_b)
  end

  test "admin of team A can update team A but not team B" do
    assert @ability.can?(:update, @team_a)
    assert @ability.cannot?(:update, @team_b)
  end

  test "admin of team A can manage users of team A but not users of team B" do
    user_a = create(:user, teams: [ @team_a ])
    user_b = create(:user, teams: [ @team_b ])

    assert @ability.can?(:update, user_a)
    assert @ability.can?(:destroy, user_a)
    assert @ability.cannot?(:update, user_b)
    assert @ability.cannot?(:destroy, user_b)
  end

  test "base membership rules are unaffected: can still read teams they belong to" do
    assert @ability.can?(:read, @team_b)
    assert @ability.can?(:menu, @team_b)
  end

  test "admin of any team can create teams" do
    assert @ability.can?(:create, Team)
  end

  test "cannot destroy self even when team admin" do
    assert @ability.cannot?(:destroy, @user)
  end

  test "a plain member has no team-admin powers on their own team" do
    plain = create(:user, teams: [ @team_a ])
    ability = Ability.new(plain)
    membership = create(:membership, team: @team_a)

    assert ability.cannot?(:manage, membership)
    assert ability.cannot?(:update, @team_a)
    assert ability.cannot?(:create, Team)
  end

  test "site admin manages every team and user regardless of memberships" do
    site_admin = create(:user, role: :site_admin, teams: [ @team_a ])
    ability = Ability.new(site_admin)

    assert ability.can?(:manage, @team_b)
    assert ability.can?(:manage, create(:user, teams: [ @team_b ]))
    assert ability.can?(:manage, create(:membership, team: @team_b))
  end
end
