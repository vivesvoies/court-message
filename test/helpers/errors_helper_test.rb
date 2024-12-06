require "test_helper"

class ErrorsHelperTest < ActiveSupport::TestCase
  include ErrorsHelper

  test "error_type_from_status returns correct error type" do
    assert_equal :forbidden, error_type_from_status(403)
    assert_equal :not_found, error_type_from_status(404)
    assert_equal :unprocessable, error_type_from_status(422)
    assert_equal :internal_server, error_type_from_status(500)
    assert_equal :unknown, error_type_from_status(418) # Teapot status code
  end
end
