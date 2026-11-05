require "test_helper"

class SmsGatewayHealthServiceTest < ActiveSupport::TestCase
  def setup
    @gateway = create(:sms_gateway, last_seen_at: Time.current)
    @line = create(:gateway_phone_line, sms_gateway: @gateway,
                   modem_ok: true, last_modem_check_at: Time.current)
    @conversation = create(:conversation)
  end

  def test_healthy_fleet_has_no_issues
    assert_empty(SmsGatewayHealthService.new.issues)
  end

  def test_reports_gateways_that_stopped_polling
    @gateway.update!(last_seen_at: 10.minutes.ago)

    issues = SmsGatewayHealthService.new.issues

    assert(issues.any? { |issue| issue.subject.include?(@gateway.name) && issue.message.include?("not polling") })
  end

  def test_reports_gateways_that_never_polled
    @gateway.update!(last_seen_at: nil)

    assert(SmsGatewayHealthService.new.issues.any? { |issue| issue.message.include?("never seen") })
  end

  def test_ignores_gateways_with_only_inactive_lines
    @gateway.update!(last_seen_at: nil)
    @line.update!(active: false)

    assert_empty(SmsGatewayHealthService.new.issues)
  end

  def test_reports_unhealthy_modems
    @line.update!(modem_ok: false, modem_details: { "error" => "ERR_TIMEOUT" })

    issues = SmsGatewayHealthService.new.issues

    assert(issues.any? { |issue| issue.message.include?("modem reported unhealthy") && issue.message.include?("ERR_TIMEOUT") })
  end

  def test_reports_stale_modem_checks
    @line.update!(last_modem_check_at: 1.hour.ago)

    assert(SmsGatewayHealthService.new.issues.any? { |issue| issue.message.include?("no modem check") })
  end

  def test_does_not_double_report_modems_when_the_gateway_is_down
    @gateway.update!(last_seen_at: 1.hour.ago)
    @line.update!(modem_ok: false)

    issues = SmsGatewayHealthService.new.issues

    assert_equal(1, issues.size)
    assert(issues.first.message.include?("not polling"))
  end

  def test_reports_unclaimed_queued_messages
    create(:outbound_message, conversation: @conversation, phone_line: @line,
           outbound_uuid: SecureRandom.uuid, created_at: 20.minutes.ago)

    issues = SmsGatewayHealthService.new.issues

    assert(issues.any? { |issue| issue.message.include?("unclaimed") })
  end

  def test_reports_stale_claims
    create(:outbound_message, conversation: @conversation, phone_line: @line,
           outbound_uuid: SecureRandom.uuid, claimed_at: 30.minutes.ago)

    issues = SmsGatewayHealthService.new.issues

    assert(issues.any? { |issue| issue.message.include?("never acknowledged") })
  end

  def test_reports_failure_streaks
    3.times do
      create(:outbound_message, conversation: @conversation, phone_line: @line,
             outbound_uuid: SecureRandom.uuid, claimed_at: 5.minutes.ago, status: :failed)
    end

    issues = SmsGatewayHealthService.new.issues

    assert(issues.any? { |issue| issue.message.include?("failed sends") })
  end

  def test_ignores_isolated_failures
    create(:outbound_message, conversation: @conversation, phone_line: @line,
           outbound_uuid: SecureRandom.uuid, claimed_at: 5.minutes.ago, status: :failed)

    assert_empty(SmsGatewayHealthService.new.issues)
  end

  def test_reports_orphaned_gateway_lines
    @line.update_columns(sms_gateway_id: nil)

    issues = SmsGatewayHealthService.new.issues

    assert(issues.any? { |issue| issue.message.include?("no gateway attached") })
  end
end
