# == Schema Information
#
# Table name: phone_lines
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  default                :boolean          default(FALSE), not null
#  fallback_after_minutes :integer
#  last_modem_check_at    :datetime
#  modem_details          :jsonb
#  modem_ok               :boolean
#  phone                  :string           not null
#  provider               :string           default("vonage"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  fallback_phone_line_id :bigint
#  sms_gateway_id         :bigint
#
# Indexes
#
#  index_phone_lines_on_fallback_phone_line_id  (fallback_phone_line_id)
#  index_phone_lines_on_phone                   (phone) UNIQUE
#  index_phone_lines_on_single_default          (default) UNIQUE WHERE ("default" = true)
#  index_phone_lines_on_sms_gateway_id          (sms_gateway_id)
#
# Foreign Keys
#
#  fk_rails_...  (fallback_phone_line_id => phone_lines.id)
#  fk_rails_...  (sms_gateway_id => sms_gateways.id)
#
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

  test "a line serving as another line's fallback cannot be deleted" do
    fallback = create(:phone_line)
    create(:gateway_phone_line, fallback_phone_line: fallback)

    assert_not(fallback.destroy)
    assert(fallback.errors[:base].present?)
    assert(PhoneLine.exists?(fallback.id))
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

  test "route_for keeps a reachable gateway line" do
    fallback = create(:phone_line)
    line = create(:gateway_phone_line, :online, fallback_phone_line: fallback)

    assert_equal(line, PhoneLine.route_for(create(:team, phone_line: line)))
  end

  test "route_for uses the fallback line when the gateway is offline" do
    fallback = create(:phone_line)
    line = create(:gateway_phone_line, :online, fallback_phone_line: fallback)
    line.sms_gateway.update!(last_seen_at: 3.minutes.ago)

    assert_equal(fallback, PhoneLine.route_for(create(:team, phone_line: line)))
  end

  test "route_for uses the fallback line when the modem reports trouble" do
    fallback = create(:phone_line)
    line = create(:gateway_phone_line, :online, fallback_phone_line: fallback)
    line.record_modem_check!(ok: false, details: { "error" => "not registered" })

    assert_equal(fallback, PhoneLine.route_for(create(:team, phone_line: line)))
  end

  test "route_for uses the fallback line when the modem stopped reporting" do
    fallback = create(:phone_line)
    line = create(:gateway_phone_line, :online, fallback_phone_line: fallback,
      last_modem_check_at: (PhoneLine::MODEM_REPORT_WITHIN + 1.minute).ago)

    assert_equal(fallback, PhoneLine.route_for(create(:team, phone_line: line)))
  end

  test "route_for tolerates a modem report delayed by a batch of sends" do
    line = create(:gateway_phone_line, :online, fallback_phone_line: create(:phone_line), last_modem_check_at: 3.minutes.ago)

    assert_equal(line, PhoneLine.route_for(create(:team, phone_line: line)))
  end

  test "route_for queues on an unreachable gateway line without a usable fallback" do
    fallback = create(:gateway_phone_line, fallback_phone_line: nil)
    line = create(:gateway_phone_line, fallback_phone_line: fallback)

    assert_equal(line, PhoneLine.route_for(create(:team, phone_line: line)))
  end

  test "route_for returns nil when nothing is active" do
    line = create(:phone_line, active: false)
    team = create(:team, phone_line: line)

    assert_nil(PhoneLine.route_for(team))
  end
end
