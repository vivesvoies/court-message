# This class provides access to the Vonage client.
class VonageProvider
  def initialize
    @client = Vonage::Client.new(
      application_id: ENV["VONAGE_APPLICATION_ID"],
      private_key: Rails.application.credentials.vonage_private_key
    )
  end

  def send(from:, to:, content:)
    message = Vonage::Messaging::Message.sms(message: content)
    @client.messaging.send(from:, to:, **message)
  end
end
