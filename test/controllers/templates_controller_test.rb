require "test_helper"

class TemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = create(:team)
    @user = create(:user, teams: [ @team ])
    @template = create(:template, user: @user)
    sign_in @user
  end

  test "should get index" do
    get team_user_templates_path(@team, @user)
    assert_response :success
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

  test "should not list another user's templates" do
    other_user = create(:user, teams: [ @team ])

    get team_user_templates_path(@team, other_user)

    assert_response :forbidden
  end

  test "should not create a template for another user" do
    other_user = create(:user, teams: [ @team ])

    assert_no_difference("Template.count") do
      post team_user_templates_path(@team, other_user), params: { template: { content: "Pas chez moi" } }
    end

    assert_response :forbidden
  end

  test "should not update another user's template" do
    other_user = create(:user, teams: [ @team ])
    other_template = other_user.templates.first

    patch team_user_template_path(@team, other_user, other_template), params: { template: { content: "hacked" } }

    assert_response :forbidden
    assert_not_equal "hacked", other_template.reload.content
  end

  test "should round-trip a title through create and update" do
    post team_user_templates_path(@team, @user), params: { template: { title: "Salutations", content: "Bonjour" } }
    template = Template.order(:created_at).last
    assert_equal "Salutations", template.title

    patch team_user_template_path(@team, @user, template), params: { template: { title: "Salutations chaleureuses" } }
    assert_equal "Salutations chaleureuses", template.reload.title
  end

  test "a team member can create a template shared with the team" do
    assert_difference("Template.count") do
      post team_user_templates_path(@team, @user), params: { template: { title: "Modèle commun", content: "Contenu partagé", shared: "1" } }
    end

    template = Template.order(:created_at).last
    assert template.shared?
    assert_equal @team.id, template.team_id
    assert_equal @user.id, template.user_id
  end

  test "another member of the same team can edit a shared template" do
    shared = create(:template, :shared, user: @user, team: @team)
    other_user = create(:user, teams: [ @team ])
    sign_in other_user

    get edit_team_user_template_path(@team, other_user, shared)
    assert_response :success

    patch team_user_template_path(@team, other_user, shared), params: { template: { content: "Mis à jour par un collègue" } }
    assert_redirected_to team_user_templates_path
    assert_equal "Mis à jour par un collègue", shared.reload.content
  end

  test "another member of the same team can destroy a shared template" do
    shared = create(:template, :shared, user: @user, team: @team)
    other_user = create(:user, teams: [ @team ])
    sign_in other_user

    assert_difference("Template.count", -1) do
      delete team_user_template_path(@team, other_user, shared)
    end
  end

  test "a member of another team cannot edit a shared template" do
    shared = create(:template, :shared, user: @user, team: @team)
    outsider = create(:user)
    sign_in outsider

    patch team_user_template_path(@team, outsider, shared), params: { template: { content: "hacked" } }

    assert_response :forbidden
    assert_not_equal "hacked", shared.reload.content
  end

  test "a member of another team cannot destroy a shared template" do
    shared = create(:template, :shared, user: @user, team: @team)
    outsider = create(:user)
    sign_in outsider

    assert_no_difference("Template.count") do
      delete team_user_template_path(@team, outsider, shared)
    end

    assert_response :forbidden
  end

  test "index exposes both personal and team templates" do
    shared = create(:template, :shared, title: "Modèle partagé", user: @user, team: @team)

    get team_user_templates_path(@team, @user)

    assert_response :success
    assert_match ERB::Util.html_escape(@template.content), response.body
    assert_match "Modèle partagé", response.body
  end
end
