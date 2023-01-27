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

    @message.status = :submitted
    @message.outbound_uuid = result.message_uuid
    @message.save

    true
  end

  private

  def default_provider = vonage_provider

  def vonage_provider
    @vonage_provider ||= VonageProvider.new
  end
end
