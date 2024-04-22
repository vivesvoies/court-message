require "test_helper"

class StaticPagesControllerTest < ActionDispatch::IntegrationTest
  test "should load legal without authentication" do
    get legal_notice_url
    assert_response :success
  end

  test "should not load ui without authentication" do
    get ui_url
    assert_response :redirect
  end
end
