# Re-routes messages stuck on a phone line to that line's fallback line
# (typically Vonage), then re-submits them through the fallback provider.
#
# A message is re-routed only when double-sending is impossible:
#   * queued (unsent) and NEVER claimed by a gateway — either past the
#     line's fallback_after_minutes deadline (automatic fallback, opt-in per
#     line) or immediately when the line was deactivated (manual fallback);
#   * reported "failed" by the gateway's modem (the SMS did not go out).
#
# Claimed-but-unacknowledged messages are deliberately left alone: the SMS
# may already have left the modem, so re-sending risks a duplicate.
# SmsGatewayHealthService raises an alert for those instead.
#
# Run periodically via `rake sms_gateway:failover` (see cron.json), or on
# demand from the Avo action on a phone line.
class MessageFallbackService
  # Modem-failed messages older than this are not retried (guards the first
  # run after a deploy or a long cron outage from resending stale history).
  FAILED_RETRY_WINDOW = 24.hours

  Result = Struct.new(:message, :submitted)

  def initialize(lines = nil)
    @lines = lines
  end

  # Returns the list of Results for every message that was re-routed.
  def run!
    lines_with_fallback.flat_map do |line|
      fallback = line.fallback_phone_line
      next [] unless fallback&.active?

      (stuck_messages(line) + failed_messages(line)).map do |message|
        fail_over!(message, from: line, to: fallback)
      end
    end
  end

  private

  def lines_with_fallback
    (@lines || PhoneLine.where.not(fallback_phone_line_id: nil)).select do |line|
      !line.active? || line.fallback_after_minutes.present?
    end
  end

  # Queued messages nobody claimed. Deadline 0 when the line was deactivated
  # by an admin (manual failover); otherwise the line's configured delay.
  def stuck_messages(line)
    deadline = line.active? ? line.fallback_after_minutes.minutes : 0.minutes

    line.messages.unsent_status
      .where(claimed_at: nil).where.not(outbound_uuid: nil)
      .where(created_at: ..deadline.ago)
      .reject { |message| already_failed_over?(message) }
  end

  # Messages whose send the modem reported as failed (claimed_at proves it
  # went through a gateway; Vonage failures are surfaced to the user at send
  # time and are not retried here).
  def failed_messages(line)
    line.messages.failed_status
      .where.not(claimed_at: nil)
      .where(updated_at: FAILED_RETRY_WINDOW.ago..)
      .reject { |message| already_failed_over?(message) }
  end

  def already_failed_over?(message)
    message.provider_info&.key?("fallback")
  end

  def fail_over!(message, from:, to:)
    message.provider_info = (message.provider_info || {}).merge(
      "fallback" => { "from" => from.phone, "to" => to.phone, "at" => Time.current.iso8601 }
    )
    message.phone_line = to
    message.claimed_at = nil

    submitted = OutboundMessagesService.new(message).submit!
    if submitted
      Rails.logger.info("[sms_gateway] message #{message.id} failed over from #{from.phone} to #{to.phone}")
    else
      Sentry.capture_message(
        "[sms_gateway] fallback submission failed: message #{message.id} from #{from.phone} to #{to.phone}"
      )
    end

    Result.new(message, submitted)
  end
end
