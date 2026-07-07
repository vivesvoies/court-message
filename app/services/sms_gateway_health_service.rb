# Evaluates the health of the SMS gateway fleet from data the gateways
# already report (last_seen_at heartbeats, per-line modem checks) and from
# the outbound queue itself. Returns a list of issues; run periodically via
# `rake sms_gateway:check_health` (see cron.json) which forwards them to
# Sentry and the logs.
class SmsGatewayHealthService
  # A gateway that has not polled for this long is considered unreachable.
  GATEWAY_SEEN_TIMEOUT = 5.minutes
  # A queued message not picked up within this delay means the line is stuck.
  QUEUE_AGE_THRESHOLD = 10.minutes
  # Recent failed sends on a line above this count trigger a warning.
  FAILURE_THRESHOLD = 3
  FAILURE_WINDOW = 1.hour

  Issue = Struct.new(:severity, :subject, :message) do
    def to_s
      "[#{severity}] #{subject}: #{message}"
    end
  end

  def issues
    stale_gateways + broken_modems + stuck_queues + stale_claims + failure_streaks + orphaned_lines
  end

  private

  # Gateways with active lines that stopped polling: Pi off, network down or
  # daemon dead.
  def stale_gateways
    SmsGateway.joins(:phone_lines).where(phone_lines: { active: true }).distinct
      .where("sms_gateways.last_seen_at IS NULL OR sms_gateways.last_seen_at < ?", GATEWAY_SEEN_TIMEOUT.ago)
      .map do |gateway|
        last_seen = gateway.last_seen_at ? "last seen #{gateway.last_seen_at.iso8601}" : "never seen"
        Issue.new(:error, "gateway #{gateway.name}", "not polling (#{last_seen})")
      end
  end

  # Lines whose gateway polls fine but whose modem reports trouble (or stopped
  # reporting): SIM/modem/antenna problem while the Pi itself is alive.
  def broken_modems
    reachable_gateway_ids = SmsGateway.where(last_seen_at: GATEWAY_SEEN_TIMEOUT.ago..).ids

    PhoneLine.active.where(provider: "sms_gateway", sms_gateway_id: reachable_gateway_ids).filter_map do |line|
      if line.modem_ok == false
        error = line.modem_details&.dig("error")
        Issue.new(:error, "line #{line.phone}", "modem reported unhealthy#{": #{error}" if error}")
      elsif line.modem_check_stale?
        Issue.new(:warning, "line #{line.phone}", "no modem check received since #{line.last_modem_check_at&.iso8601 || 'ever'}")
      end
    end
  end

  # Dispatched messages nobody claimed: the daemon for that line is not
  # picking up work.
  def stuck_queues
    per_line_issues(
      Message.unsent_status.where(claimed_at: nil).where.not(outbound_uuid: nil)
        .where(created_at: ..QUEUE_AGE_THRESHOLD.ago)
    ) do |line, messages|
      oldest = messages.map(&:created_at).min
      Issue.new(:error, "line #{line.phone}", "#{messages.size} queued message(s) unclaimed, oldest since #{oldest.iso8601}")
    end
  end

  # Claimed but never acknowledged past the claim timeout: the modem accepted
  # the claim but could not finish sending. These are NOT re-routed
  # automatically (the SMS may have left the modem) — a human must decide.
  def stale_claims
    per_line_issues(
      Message.unsent_status.where(claimed_at: ..SmsGateway::CLAIM_TIMEOUT.ago)
    ) do |line, messages|
      Issue.new(:error, "line #{line.phone}",
        "#{messages.size} claimed message(s) never acknowledged (possible duplicate risk, manual action required)")
    end
  end

  # Repeated modem-reported failures.
  def failure_streaks
    per_line_issues(
      Message.failed_status.where.not(claimed_at: nil).where(updated_at: FAILURE_WINDOW.ago..)
    ) do |line, messages|
      next if messages.size < FAILURE_THRESHOLD

      Issue.new(:warning, "line #{line.phone}", "#{messages.size} failed sends in the last #{FAILURE_WINDOW.inspect}")
    end
  end

  # Misconfiguration guard: an active sms_gateway line without a gateway can
  # queue messages forever with nothing to claim them.
  def orphaned_lines
    PhoneLine.active.where(provider: "sms_gateway", sms_gateway_id: nil).map do |line|
      Issue.new(:error, "line #{line.phone}", "sms_gateway line has no gateway attached; queued messages can never be sent")
    end
  end

  def per_line_issues(scope, &block)
    scope.where.not(phone_line_id: nil).includes(:phone_line)
      .group_by(&:phone_line)
      .filter_map { |line, messages| block.call(line, messages) }
  end
end
