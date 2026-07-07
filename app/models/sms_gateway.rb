# == Schema Information
#
# Table name: sms_gateways
#
#  id           :bigint           not null, primary key
#  last_seen_at :datetime
#  name         :string           not null
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_sms_gateways_on_name          (name) UNIQUE
#  index_sms_gateways_on_token_digest  (token_digest) UNIQUE
#
# A physical SMS gateway device (e.g. a Raspberry Pi with one or more SIM
# modems) that we control. Gateways never receive connections: they poll the
# app over HTTPS, authenticated with a bearer token. Only a SHA-256 digest of
# the token is stored; the plaintext token is shown once at provisioning time.
class SmsGateway < ApplicationRecord
  # A claimed message that was not acknowledged within this window becomes
  # claimable again (e.g. the gateway crashed mid-send).
  CLAIM_TIMEOUT = 10.minutes

  has_many :phone_lines, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true

  # Creates a gateway and returns it along with its plaintext API token.
  # The token cannot be recovered later, only rotated.
  def self.provision!(name:)
    token = generate_token
    gateway = create!(name:, token_digest: digest(token))
    [ gateway, token ]
  end

  def self.authenticate_by_token(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))
  end

  def self.generate_token
    SecureRandom.base58(32)
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def rotate_token!
    token = self.class.generate_token
    update!(token_digest: self.class.digest(token))
    token
  end

  def touch_last_seen!
    update_column(:last_seen_at, Time.current)
  end

  # Atomically claims up to `limit` outbound messages queued on this
  # gateway's phone lines. Uses FOR UPDATE SKIP LOCKED so several gateways
  # (or concurrent polls) never claim the same message twice. Messages
  # claimed longer than CLAIM_TIMEOUT ago but never acknowledged are
  # re-claimed. When the gateway drives several SIM modems (one polling
  # process per modem), `phone` restricts the claim to a single line.
  def claim_messages!(limit: 10, phone: nil)
    scope = Message.joins(:phone_line).where(phone_lines: { sms_gateway_id: id })
    scope = scope.where(phone_lines: { phone: PhonyRails.normalize_number(phone) }) if phone.present?

    Message.transaction do
      ids = scope
        .unsent_status
        .where("messages.claimed_at IS NULL OR messages.claimed_at < ?", CLAIM_TIMEOUT.ago)
        .order(:created_at)
        .limit(limit)
        .lock("FOR UPDATE OF messages SKIP LOCKED")
        .pluck(:id)

      Message.where(id: ids).update_all(claimed_at: Time.current, updated_at: Time.current)
      Message.where(id: ids).order(:created_at)
    end
  end

  # Scopes a message lookup to this gateway's lines, for status callbacks.
  def messages
    Message.joins(:phone_line).where(phone_lines: { sms_gateway_id: id })
  end
end
