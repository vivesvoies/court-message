require "test_helper"

class PhoneLineTest < ActiveSupport::TestCase
  test "normalizes the phone number" do
    line = create(:phone_line, phone: "06 44 63 00 57")

    assert_equal("+33644630057", line.phone)
  end

  test "rejects implausible phone numbers" do
    line = build(:phone_line, phone: "123")

    assert_not(line.valid?)
  end

  test "phone must be unique" do
    line = create(:phone_line)

    assert_raises(ActiveRecord::RecordInvalid) { create(:phone_line, phone: line.phone) }
  end

  test "provider must be known" do
    line = build(:phone_line, provider: "carrier_pigeon")

    assert_not(line.valid?)
  end

  test "sms_gateway lines require a gateway" do
    line = build(:phone_line, provider: "sms_gateway", sms_gateway: nil)

    assert_not(line.valid?)
    assert(line.errors[:sms_gateway].present?)
  end

  test "only one line can be the default" do
    create(:phone_line, default: true)
    second = build(:phone_line, default: true)

    assert_not(second.valid?)
  end

  test "default_line returns the default line" do
    create(:phone_line)
    default = create(:phone_line, default: true)

    assert_equal(default, PhoneLine.default_line)
  end

  test "fallback line cannot be the line itself" do
    line = create(:phone_line)
    line.fallback_phone_line = line

    assert_not(line.valid?)
  end

  test "route_for prefers the team's line" do
    create(:phone_line, default: true)
    line = create(:phone_line)
    team = create(:team, phone_line: line)

    assert_equal(line, PhoneLine.route_for(team))
  end

  test "route_for falls back to the default line" do
    default = create(:phone_line, default: true)

    assert_equal(default, PhoneLine.route_for(create(:team)))
    assert_equal(default, PhoneLine.route_for(nil))
  end

  test "route_for uses the fallback line when the preferred line is inactive" do
    fallback = create(:phone_line)
    line = create(:phone_line, active: false, fallback_phone_line: fallback)
    team = create(:team, phone_line: line)

    assert_equal(fallback, PhoneLine.route_for(team))
  end

  test "route_for uses the default line when line and fallback are inactive" do
    default = create(:phone_line, default: true)
    fallback = create(:phone_line, active: false)
    line = create(:phone_line, active: false, fallback_phone_line: fallback)
    team = create(:team, phone_line: line)

    assert_equal(default, PhoneLine.route_for(team))
  end

  test "route_for returns nil when nothing is active" do
    line = create(:phone_line, active: false)
    team = create(:team, phone_line: line)

    assert_nil(PhoneLine.route_for(team))
  end
end
