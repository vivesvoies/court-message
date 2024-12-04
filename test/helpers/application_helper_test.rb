require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  include ApplicationHelper

  def test_time_stamp_for
    today = Time.current.beginning_of_day
    yesterday = Time.zone.now - 1.day
    this_week = Time.zone.now - 4.days
    past = Time.zone.now - 8.days
    future = Time.zone.now + 1.day

    assert_match(/\d+:\d+/, time_stamp_for(today))
    assert_match(I18n.t("date.yesterday"), time_stamp_for(yesterday))
    assert_match(/\w+/, time_stamp_for(this_week)) # Careful, brittle for some languages
    assert_match(/\d+\/\d+\/\d+/, time_stamp_for(past))
    assert_match(/\d+\/\d+\/\d+/, time_stamp_for(future))
  end

  test "error_type_from_status returns correct error type" do
    assert_equal :forbidden, error_type_from_status(403)
    assert_equal :not_found, error_type_from_status(404)
    assert_equal :unprocessable, error_type_from_status(422)
    assert_equal :internal_server, error_type_from_status(500)
  end

  test "error_type_from_status returns nil for unknown status" do
    assert_nil error_type_from_status(418) # Teapot status code
    assert_nil error_type_from_status(999) # Arbitrary unknown status
  end
end
