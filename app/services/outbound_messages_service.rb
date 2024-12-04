# This class is responsible for sending outbound messages.
# It will create a Message instance with a status of not-yet-delivered.
# Currently only supports SMS through Vonage.
class OutboundMessagesService
  attr_reader :message

  def initialize(message, provider = nil)
    @message = message
    @message.status = :unsent

    @provider = provider || default_provider
  end

  def submit!
    # TODO: Optimization / preloading?
    to = @message.conversation.contact.phone
    result = @provider.send(from: Current.phone_number, to:, content: @message.content)

    @message.status = result.http_response.is_a?(Net::HTTPSuccess) ? :submitted : :failed
    @message.outbound_uuid = result.message_uuid
    @message.save

    if result.http_response.is_a?(Net::HTTPSuccess)
      true
    else
      if result.http_response?
        Sentry.capture_message(
          "Outbound message failed in OutboundMessagesService: Message UUID #{result.message_uuid}, " \
          "HTTP Status: #{result.http_response.code}, Response Body: #{result.http_response.body}."
        )
      end
      false
    end
  end

  private

  def default_provider
    unless Rails.env.test?
      vonage_provider
    else
      DummyProvider.new
    end
  end

  def vonage_provider
    @vonage_provider ||= VonageProvider.new
  end
end
