require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  def with_normal_user
    @teams = create_list(:team, 3)
    @user = create(:user, teams: @teams)
    @team = @user.teams.first
    sign_in @user
  end

  def with_team_admin
    @user = create(:user, role: :team_admin)
    @team = @user.teams.first
    sign_in @user
  end

  ### Normal users

  test "should show picker on index" do
    with_normal_user
    get teams_url
    assert_response :success
  end

  test "should not show edit buttons on picker" do
    with_normal_user
    get teams_url
    assert_select "[href=\"#{edit_team_path(@team)}\"]", count: 0
  end

  test "should not display new team button to non-admins" do
    with_normal_user
    get teams_url
    assert_select "[href=\"#{new_team_path}\"]", count: 0
  end

  test "should redirect normal users to their team if team.count is 1" do
    user = create(:user)
    assert_equal(1, user.teams.count)

    sign_in user
    get teams_url
    assert_redirected_to(team_conversations_url(user.teams.first))
  end

  test "should show picker when param is set" do
    user = create(:user)
    assert_equal(1, user.teams.count)

    sign_in user
    get teams_url(picker: "show")
    assert_response :success
  end

  test "should show a message to teamless users" do
    user = create(:user, teams: [])
    assert_equal(0, user.teams.count)

    sign_in user
    get teams_url
    assert_select "p", text: I18n.t("teams.index.no_team")
  end

  test "should not get new" do
    with_normal_user
    get new_team_url
    assert_response :forbidden
  end

  test "should create not team" do
    with_normal_user
    assert_no_difference("Team.count") do
      post teams_url, params: { team: { name: "Team Name" } }
    end

    assert_response :forbidden
  end

  test "should show conversations on GET /team/:id" do
    with_normal_user
    get team_url(@team)
    assert_redirected_to team_conversations_url(@team)
  end

  test "should not get edit" do
    with_normal_user
    get edit_team_url(@team)
    assert_response :forbidden
  end

  test "should not update team" do
    with_normal_user
    patch team_url(@team), params: { team: {} }
    assert_response :forbidden
  end

  test "should not destroy team" do
    with_normal_user
    assert_no_difference("Team.count") do
      delete team_url(@team)
    end
    assert_response :forbidden
  end

  ### Admins

  test "should get index even with only one team" do
    with_team_admin
    assert_equal(1, @user.teams.count)

    get teams_url
    assert_response :success
  end

  test "should show edit buttons on picker" do
    with_team_admin
    get teams_url
    assert_select "[href=\"#{edit_team_path(@team)}\"]", count: 1
  end

  test "should display new team button to admins" do
    with_team_admin
    get teams_url
    assert_select "[href=\"#{new_team_path}\"]", count: 1
  end

  test "should get new" do
    with_team_admin
    get new_team_url
    assert_response :success
  end

  test "should create team" do
    with_team_admin
    assert_difference("Team.count") do
      post teams_url, params: { team: { name: "Team Name" } }
    end

    assert_redirected_to team_url(Team.last)
  end

  test "should get edit" do
    with_team_admin
    get edit_team_url(@team)
    assert_response :success
  end

  test "should update team" do
    with_team_admin
    patch team_url(@team), params: { team: {} }
    assert_redirected_to team_url(@team)
  end

  test "should destroy team" do
    with_team_admin
    assert_difference("Team.count", -1) do
      delete team_url(@team)
    end

    assert_redirected_to teams_url
  end

  test "should not destroy other team" do
    with_team_admin
    other_team = create(:team)
    
    assert_no_difference("Team.count") do
      delete team_url(other_team)
    end

    assert_response :forbidden
  end

end
