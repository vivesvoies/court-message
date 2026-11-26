module MessagesHelper
  # The status shown under a message, or nil when its fate is unknown: still
  # queued for a gateway, or handed to a SIM gateway's network without a
  # delivery report (yet, or ever). Only gateways claim messages, so
  # claimed_at tells them from Vonage's, whose "submitted" always resolves.
  def message_status_label(message)
    return if message.unsent_status?
    return if message.submitted_status? && message.claimed_at.present?

    t("messages.status.#{message.status}")
  end
end
