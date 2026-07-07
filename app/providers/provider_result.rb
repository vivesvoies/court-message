# Normalized result returned by every provider's #send, so that
# OutboundMessagesService does not depend on provider-specific response
# shapes (e.g. Vonage's Net::HTTP response).
class ProviderResult
  attr_reader :message_uuid, :error, :raw

  def initialize(success:, message_uuid: nil, queued: false, error: nil, raw: nil)
    @success = success
    @message_uuid = message_uuid
    @queued = queued
    @error = error
    @raw = raw
  end

  # The provider accepted the message (sent or queued for sending).
  def success?
    @success
  end

  # The message is queued on our side and will be picked up asynchronously
  # (SMS gateways poll for their messages); it has not reached a carrier yet.
  def queued?
    @queued
  end
end
