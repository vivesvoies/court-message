require "test_helper"

class TemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = create(:team)
    @user = create(:user, teams: [ @team ])
    @template = create(:template, user: @user)
    sign_in @user
  end

  test "should get new" do
    get new_team_user_template_path(@team, @user)
    assert_response :success
  end

  test "should create template" do
    assert_difference("Template.count") do
      post team_user_templates_path(@team, @user), params: { template: { content: "Template content" } }
    end

    assert_redirected_to team_user_templates_path(@team, @user)
    # assert_equal I18n.t("templates.create.success") , flash[:notice]
  end

  test "should not create template without content" do
    assert_no_difference("Template.count") do
      post team_user_templates_path(@team, @user), params: { template: { content: nil } }
    end

    assert_redirected_to team_user_templates_path(@team, @user)
    # assert_equal I18n.t("templates.create.not_blank"), flash[:notice]
  end

  test "should show template" do
    get team_user_template_path(@team, @user, @template)
    assert_redirected_to(team_user_templates_path(@team, @user))
  end

  test "should get edit" do
    get edit_team_user_template_path(@team, @user, @template)
    assert_response :success
  end

  test "should update template" do
    patch team_user_template_path(@team, @user, @template), params: { template: { content: "Updated template content" } }
    assert_redirected_to team_user_templates_path(@team, @user)
  end

  test "should not update template with invalid content" do
    patch team_user_template_path(@team, @user, @template), params: { template: { content: nil } }
    assert_response :unprocessable_entity
  end

  test "should destroy template" do
    assert_difference("Template.count", -1) do
      delete team_user_template_path(@team, @user, @template)
    end

    assert_redirected_to team_user_templates_path(@team, @user)
  end
end
