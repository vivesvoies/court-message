# Authenticates webhook requests using the JWT that Vonage attaches to them.
# https://developer.vonage.com/en/getting-started/concepts/webhooks#validating-signed-webhooks
#
# The token is signed (HS256) with the account's signature secret, configured
# via the VONAGE_SIGNATURE_SECRET environment variable or the
# vonage_signature_secret credential.
module VonageWebhookAuthentication
  extend ActiveSupport::Concern

  # All rejections share one fingerprint so they group into a single Sentry
  # issue: this endpoint is public and collects unauthenticated scanner traffic,
  # which would otherwise drown the signal in one issue per request.
  REJECTION_FINGERPRINT = [ "vonage-webhook-signature-rejected" ].freeze

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

    reason = webhook_signature_failure(secret)
    reject_webhook!(reason) if reason
  end

  # Returns nil when the request is authentic, otherwise a short reason.
  def webhook_signature_failure(secret)
    scheme, token = request.authorization&.split(" ", 2)
    return "no bearer token" unless scheme == "Bearer" && token.present?

    claims, _header = JWT.decode(token, secret, true, algorithm: "HS256")

    # Vonage binds the token to the body with a payload_hash claim (SHA-256 of
    # the raw JSON). Accepting a token without one would make that binding
    # bypassable, so it is required rather than optional.
    return "no payload_hash claim" if claims["payload_hash"].blank?

    expected = Digest::SHA256.hexdigest(request.raw_post)
    return "payload_hash mismatch" unless ActiveSupport::SecurityUtils.secure_compare(claims["payload_hash"].to_s, expected)

    nil
  rescue JWT::DecodeError => e
    "invalid token (#{e.class})"
  end

  def reject_webhook!(reason)
    Rails.logger.warn("Vonage webhook rejected: #{reason}")
    Sentry.capture_message(
      "Vonage webhook signature rejected",
      level: :warning,
      fingerprint: REJECTION_FINGERPRINT,
      extra: { reason:, path: request.path }
    )
    head :unauthorized
  end

  def vonage_signature_secret
    ENV["VONAGE_SIGNATURE_SECRET"].presence || Rails.application.credentials.vonage_signature_secret
  end
end
