require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = create(:team)
    @other_team = create(:team)
    @user = create(:user, role: :user, teams: [ @team ])
  end

  test "should render forbidden page with status 403" do
    get "/403"
    assert_response :forbidden
    assert_match /403 - Accès refusé/, response.body
  end

  test "should render not found page with status 404" do
    get "/404"
    assert_response :not_found
    assert_match /404 - Page non trouvée/, response.body
  end

  test "should render unprocessable page with status 422" do
    get "/422"
    assert_response :unprocessable_entity
    assert_match /422 - Entité non traitable/, response.body
  end

  test "should render internal server error page with status 500" do
    get "/500"
    assert_response :internal_server_error
    assert_match /500 - Erreur interne du serveur/, response.body
  end

  test "should render not found page for unknown routes" do
    simulate_production_error_handling do
      get "/unknown_routes"
      assert_response :not_found
      assert_match /404 - Page non trouvée/, response.body
    end
  end

  test "should render forbidden page with status 403 for unauthorized action" do
    simulate_production_error_handling do
      sign_in @user
      get team_url(@other_team, @user)
      assert_response :forbidden
      assert_match /403 - Accès refusé/, response.body
      sign_out @user
    end
  end

  def simulate_production_error_handling
    env_config = Rails.application.env_config
    original_requests_local = env_config["consider_all_requests_local"]
    original_show_exceptions = env_config["action_dispatch.show_exceptions"]
    original_show_detailed_exceptions = env_config["action_dispatch.show_detailed_exceptions"]
    env_config["consider_all_requests_local"] = false
    env_config["action_dispatch.show_exceptions"] = true
    env_config["action_dispatch.show_detailed_exceptions"] = false
    yield
  ensure
    env_config["consider_all_requests_local"] = original_requests_local
    env_config["action_dispatch.show_exceptions"] = original_show_exceptions
    env_config["action_dispatch.show_detailed_exceptions"] = original_show_detailed_exceptions
  end
end
