# This class is responsible for submitting outbound messages to the provider.
# Currently only supports SMS through Vonage.
class OutboundMessagesService
  # Raised when the provider does not accept the message, so the caller
  # (MessageDeliveryJob) can retry with backoff.
  class DeliveryError < StandardError; end

  attr_reader :message

  def initialize(message, provider = nil)
    @message = message
    @provider = provider || default_provider
  end

  # Submits the message to the provider. On success the message becomes
  # "submitted"; on refusal a DeliveryError is raised and the message keeps
  # its current status so a retry can pick it up.
  def submit!
    to = @message.conversation.contact.phone
    from = Rails.configuration.x.outbound_phone_number
    result = @provider.send(from:, to:, content: @message.content)

    unless result.http_response.is_a?(Net::HTTPSuccess)
      raise DeliveryError, "Provider refused message #{@message.id}: " \
        "HTTP #{result.http_response&.code} #{result.http_response&.message}"
    end

    @message.update!(status: :submitted, outbound_uuid: result.message_uuid)
    true
  end

  private

  def default_provider
    Rails.env.test? ? DummyProvider.new : VonageProvider.new
  end
end
