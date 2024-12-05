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
end
