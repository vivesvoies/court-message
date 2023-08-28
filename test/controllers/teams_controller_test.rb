require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  def setupNormalUser
    @teams = create_list(:team, 3)
    @user = create(:user, teams: @teams)
    @team = @user.teams.first
    sign_in @user
  end

  def setupTeamAdmin
    @user = create(:user, role: :team_admin)
    @team = @user.teams.first
    sign_in @user
  end

  ### Normal users

  test "should show picker on index" do
    setupNormalUser
    get teams_url
    assert_response :success
  end

  test "should not show edit buttons on picker" do
    setupNormalUser
    get teams_url
    assert_select "[href=\"#{edit_team_path(@team)}\"]", count: 0
  end

  test "should not display new team button to non-admins" do
    setupNormalUser
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
    setupNormalUser
    get new_team_url
    assert_response :forbidden
  end

  test "should create not team" do
    setupNormalUser
    assert_no_difference("Team.count") do
      post teams_url, params: { team: { name: "Team Name" } }
    end

    assert_response :forbidden
  end

  test "should show conversations on GET /team/:id" do
    setupNormalUser
    get team_url(@team)
    assert_redirected_to team_conversations_url(@team)
  end

  test "should not get edit" do
    setupNormalUser
    get edit_team_url(@team)
    assert_response :forbidden
  end

  test "should not update team" do
    setupNormalUser
    patch team_url(@team), params: { team: {} }
    assert_response :forbidden
  end

  test "should not destroy team" do
    setupNormalUser
    assert_no_difference("Team.count") do
      delete team_url(@team)
    end
    assert_response :forbidden
  end

  ### Admins

  test "should get index even with only one team" do
    setupTeamAdmin
    assert_equal(1, @user.teams.count)

    get teams_url
    assert_response :success
  end

  test "should show edit buttons on picker" do
    setupTeamAdmin
    get teams_url
    assert_select "[href=\"#{edit_team_path(@team)}\"]", count: 1
  end

  test "should display new team button to admins" do
    setupTeamAdmin
    get teams_url
    assert_select "[href=\"#{new_team_path}\"]", count: 1
  end

  test "should get new" do
    setupTeamAdmin
    get new_team_url
    assert_response :success
  end

  test "should create team" do
    setupTeamAdmin
    assert_difference("Team.count") do
      post teams_url, params: { team: { name: "Team Name" } }
    end

    assert_redirected_to team_url(Team.last)
  end

  test "should get edit" do
    setupTeamAdmin
    get edit_team_url(@team)
    assert_response :success
  end

  test "should update team" do
    setupTeamAdmin
    patch team_url(@team), params: { team: {} }
    assert_redirected_to team_url(@team)
  end

  test "should destroy team" do
    setupTeamAdmin
    assert_difference("Team.count", -1) do
      delete team_url(@team)
    end

    assert_redirected_to teams_url
  end

  test "should not destroy other team" do
    setupTeamAdmin
    other_team = create(:team)
    
    assert_no_difference("Team.count") do
      delete team_url(other_team)
    end

    assert_response :forbidden
  end

end
