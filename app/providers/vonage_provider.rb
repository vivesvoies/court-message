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
    response = @client.messaging.send(from:, to:, **message)

    if response.http_response.is_a?(Net::HTTPSuccess)
      ProviderResult.new(success: true, message_uuid: response.message_uuid, raw: response)
    else
      error = if response.http_response?
        "HTTP Status: #{response.http_response.code}, Response Body: #{response.http_response.body}."
      end
      ProviderResult.new(success: false, error:, raw: response)
    end
  rescue Vonage::Error => e
    ProviderResult.new(success: false, error: "#{e.class}: #{e.message}")
  end
end
