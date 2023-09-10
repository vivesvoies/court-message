require "test_helper"

class ReadStatusControllerTest < ActionDispatch::IntegrationTest
  test "should get update" do
    get read_status_update_url
    assert_response :success
  end
end
