require "test_helper"

class TeamsControllerTest
  class NormalUsers < ActionDispatch::IntegrationTest
    setup do
      @teams = create_list(:team, 3)
      @user = create(:user, teams: @teams)
      @team = @user.teams.first
      sign_in @user
    end

    test "should get index" do
      get teams_url
      assert_response :success
    end

    test "should not display new team button to non-admins" do
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
      get new_team_url
      assert_response :forbidden
    end

    test "should create not team" do
      assert_no_difference("Team.count") do
        post teams_url, params: { team: { name: "Team Name" } }
      end

      assert_response :forbidden
    end

    test "should show conversations on GET /team/:id" do
      get team_url(@team)
      assert_redirected_to team_conversations_url(@team)
    end

    test "should not get edit" do
      get edit_team_url(@team)
      assert_response :forbidden
    end

    test "should not update team" do
      patch team_url(@team), params: { team: {} }
      assert_response :forbidden
    end

    test "should not destroy team" do
      assert_no_difference("Team.count") do
        delete team_url(@team)
      end
      assert_response :forbidden
    end
  end

  class TeamAdmin < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user, role: :team_admin)
      @team = @user.teams.first
      sign_in @user
    end

    test "should get index even with only one team" do
      assert_equal(1, @user.teams.count)

      get teams_url
      assert_response :success
    end

    test "should display new team button to admins" do
      get teams_url
      assert_select "[href=\"#{new_team_path}\"]", count: 1
    end

    test "should get new" do
      get new_team_url
      assert_response :success
    end

    test "should create team" do
      assert_difference("Team.count") do
        post teams_url, params: { team: { name: "Team Name" } }
      end

      assert_redirected_to team_url(Team.last)
    end

    test "should get edit" do
      get edit_team_url(@team)
      assert_response :success
    end

    test "should update team" do
      patch team_url(@team), params: { team: {} }
      assert_redirected_to team_url(@team)
    end

    test "should destroy team" do
      assert_difference("Team.count", -1) do
        delete team_url(@team)
      end

      assert_redirected_to teams_url
    end

    test "should not destroy other team" do
      other_team = create(:team)
      
      assert_no_difference("Team.count") do
        delete team_url(other_team)
      end

      assert_response :forbidden
    end

  end
end
