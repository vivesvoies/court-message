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
end
