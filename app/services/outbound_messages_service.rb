# This class is responsible for sending outbound messages.
# It will create a Message instance with a status of not-yet-delivered.
# Supports SMS through Vonage (API) and through our own SMS gateways
# (SIM modems polling the app, see SmsGatewayProvider).
class OutboundMessagesService
  attr_reader :message

  def initialize(message, provider = nil)
    @message = message
    @message.status = :unsent
    # Routed from the message's own team so sends work identically from
    # requests, rake tasks (fallback re-routing) and the console.
    @message.phone_line ||= PhoneLine.route_for(@message.conversation&.team)

    @provider = provider || provider_for(@message.phone_line)
  end

  def submit!
    # TODO: Optimization / preloading?
    to = @message.conversation.contact.phone
    result = @provider.send(from: from_number, to:, content: @message.content)

    # Queued messages stay "unsent" until the gateway picks them up and
    # reports back; direct API sends move straight to "submitted".
    @message.status = if result.success?
      result.queued? ? :unsent : :submitted
    else
      :failed
    end
    @message.outbound_uuid = result.message_uuid
    @message.save

    if result.success?
      true
    else
      if result.error
        Sentry.capture_message(
          "Outbound message failed in OutboundMessagesService: Message UUID #{result.message_uuid}, #{result.error}"
        )
      end
      false
    end
  end

  private

  def from_number
    @message.phone_line&.phone || PhoneLine.legacy_number
  end

  def provider_for(phone_line)
    if phone_line&.sms_gateway_provider?
      SmsGatewayProvider.new
    elsif Rails.env.test?
      DummyProvider.new
    else
      vonage_provider
    end
  end

  def vonage_provider
    @vonage_provider ||= VonageProvider.new
  end
end
