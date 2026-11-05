# This class provides access to the Vonage client.
class VonageProvider
  # The Vonage SDK lets transport errors through unwrapped. Reported as a
  # failed send like any API error, so callers (a user's send, the fallback
  # run) handle them instead of crashing.
  NETWORK_ERRORS = [ Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError ].freeze

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
  rescue Vonage::Error, *NETWORK_ERRORS => e
    ProviderResult.new(success: false, error: "#{e.class}: #{e.message}")
  end
end
