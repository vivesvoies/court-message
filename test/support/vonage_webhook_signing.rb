# Helpers to exercise webhook endpoints with (in)valid Vonage JWT signatures.
module VonageWebhookSigning
  SIGNATURE_SECRET = "test-signature-secret"

  # Runs the block with webhook authentication enabled.
  def with_signature_secret(secret = SIGNATURE_SECRET)
    ENV["VONAGE_SIGNATURE_SECRET"] = secret
    yield
  ensure
    ENV.delete("VONAGE_SIGNATURE_SECRET")
  end

  # Headers for a signed JSON webhook request whose raw body is +body+.
  def signed_webhook_headers(body, secret: SIGNATURE_SECRET, payload_hash: nil)
    claims = {
      api_key: "test-api-key",
      iat: Time.now.to_i,
      jti: SecureRandom.uuid,
      payload_hash: payload_hash || Digest::SHA256.hexdigest(body)
    }
    {
      "Authorization" => "Bearer #{JWT.encode(claims, secret, "HS256")}",
      "CONTENT_TYPE" => "application/json"
    }
  end
end
