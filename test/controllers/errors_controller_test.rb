require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
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
end
