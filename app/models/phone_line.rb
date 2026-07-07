# == Schema Information
#
# Table name: phone_lines
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  default                :boolean          default(FALSE), not null
#  fallback_after_minutes :integer
#  last_modem_check_at    :datetime
#  modem_details          :jsonb
#  modem_ok               :boolean
#  phone                  :string           not null
#  provider               :string           default("vonage"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  fallback_phone_line_id :bigint
#  sms_gateway_id         :bigint
#
# Indexes
#
#  index_phone_lines_on_default                 ("default") UNIQUE WHERE ("default" = true)
#  index_phone_lines_on_fallback_phone_line_id  (fallback_phone_line_id)
#  index_phone_lines_on_phone                   (phone) UNIQUE
#  index_phone_lines_on_sms_gateway_id          (sms_gateway_id)
#
# Foreign Keys
#
#  fk_rails_...  (fallback_phone_line_id => phone_lines.id)
#  fk_rails_...  (sms_gateway_id => sms_gateways.id)
#
# A sender phone number and the provider that carries its traffic: either
# Vonage (API) or one of our own SMS gateways (SIM card in a device we
# control). Teams can be attached to a line; otherwise the default line is
# used, falling back to the legacy env-based Vonage number.
#
# A line can name a fallback line (typically Vonage): new sends are routed
# there while the line is inactive, and MessageFallbackService re-routes
# stuck or modem-failed messages there (automatically when
# fallback_after_minutes is set, or after an admin deactivates the line).
class PhoneLine < ApplicationRecord
  PROVIDERS = %w[vonage sms_gateway].freeze

  # A modem report older than this is treated as unknown/unhealthy.
  MODEM_CHECK_TIMEOUT = 15.minutes

  belongs_to :sms_gateway, optional: true
  belongs_to :fallback_phone_line, class_name: "PhoneLine", optional: true
  has_many :teams, dependent: :nullify
  has_many :messages, dependent: :nullify

  phony_normalize :phone
  validates :phone, presence: true, uniqueness: true, phony_plausible: true
  validates :provider, inclusion: { in: PROVIDERS }
  validates :sms_gateway, presence: true, if: :sms_gateway_provider?
  # Backed by a partial unique index for race safety.
  validates :default, uniqueness: true, if: :default?
  validates :fallback_after_minutes, numericality: { greater_than: 0, allow_nil: true }
  validate :fallback_is_not_self

  scope :active, -> { where(active: true) }

  def self.default_line
    find_by(default: true)
  end

  # The sender number used before phone lines existed, kept as a last-resort
  # fallback so the app works with no PhoneLine rows at all.
  def self.legacy_number
    case Rails.env.to_sym
    when :staging
      "33644639777"
    when :production
      "33644635900"
    else
      "33644630057"
    end
  end

  # The line an outbound message for this team should use:
  # the team's line, or the default line; when that line is deactivated,
  # its fallback line (one hop), then the default line. May return nil
  # (callers fall back to legacy_number over Vonage).
  def self.route_for(team)
    preferred = team&.phone_line || default_line
    return preferred if preferred.nil? || preferred.active?

    fallback = preferred.fallback_phone_line
    return fallback if fallback&.active?

    default = default_line
    default&.active? ? default : nil
  end

  def vonage_provider?
    provider == "vonage"
  end

  def sms_gateway_provider?
    provider == "sms_gateway"
  end

  def formatted_phone
    phone.phony_formatted(format: :national)
  end

  def record_modem_check!(ok:, details: nil)
    update_columns(modem_ok: ok, modem_details: details, last_modem_check_at: Time.current)
  end

  def modem_check_stale?
    last_modem_check_at.nil? || last_modem_check_at < MODEM_CHECK_TIMEOUT.ago
  end

  private

  def fallback_is_not_self
    errors.add(:fallback_phone_line, :invalid) if fallback_phone_line_id.present? && fallback_phone_line_id == id
  end
end
