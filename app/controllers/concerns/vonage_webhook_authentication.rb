# Authenticates webhook requests using the JWT that Vonage attaches to them.
# https://developer.vonage.com/en/getting-started/concepts/webhooks#validating-signed-webhooks
#
# The token is signed (HS256) with the account's signature secret, configured
# via the VONAGE_SIGNATURE_SECRET environment variable or the
# vonage_signature_secret credential.
module VonageWebhookAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_webhook!
  end

  private

  def authenticate_webhook!
    secret = vonage_signature_secret

    if secret.blank?
      # Accept the request so that messages are not lost before the secret is
      # provisioned, but make noise: webhooks are unauthenticated until then.
      Rails.logger.warn("Vonage signature secret not configured; webhook accepted without authentication")
      Sentry.capture_message("Vonage signature secret is not configured; webhooks are NOT authenticated")
      return
    end

    head :unauthorized unless valid_webhook_signature?(secret)
  end

  def valid_webhook_signature?(secret)
    scheme, token = request.authorization&.split(" ", 2)
    return false unless scheme == "Bearer" && token.present?

    claims, _header = JWT.decode(token, secret, true, algorithm: "HS256")
    valid_webhook_payload_hash?(claims)
  rescue JWT::DecodeError
    false
  end

  # Vonage includes a payload_hash claim (SHA-256 of the raw JSON body) so the
  # payload can't be swapped under a valid token.
  #
  # The claim is required, not optional: treating a missing claim as valid would
  # make the binding bypassable, and a captured token would then authenticate any
  # body. Vonage always sends it, so a token without one is anomalous enough to
  # report rather than reject silently.
  def valid_webhook_payload_hash?(claims)
    if claims["payload_hash"].blank?
      Sentry.capture_message("Vonage webhook token carried no payload_hash claim; request rejected")
      return false
    end

    expected = Digest::SHA256.hexdigest(request.raw_post)
    ActiveSupport::SecurityUtils.secure_compare(claims["payload_hash"].to_s, expected)
  end

  def vonage_signature_secret
    ENV["VONAGE_SIGNATURE_SECRET"].presence || Rails.application.credentials.vonage_signature_secret
  end
end
