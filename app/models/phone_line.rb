# == Schema Information
#
# Table name: phone_lines
#
#  id             :bigint           not null, primary key
#  default        :boolean          default(FALSE), not null
#  phone          :string           not null
#  provider       :string           default("vonage"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  sms_gateway_id :bigint
#
# Indexes
#
#  index_phone_lines_on_default         ("default") UNIQUE WHERE ("default" = true)
#  index_phone_lines_on_phone           (phone) UNIQUE
#  index_phone_lines_on_sms_gateway_id  (sms_gateway_id)
#
# Foreign Keys
#
#  fk_rails_...  (sms_gateway_id => sms_gateways.id)
#
# A sender phone number and the provider that carries its traffic: either
# Vonage (API) or one of our own SMS gateways (SIM card in a device we
# control). Teams can be attached to a line; otherwise the default line is
# used, falling back to the legacy env-based Vonage number.
class PhoneLine < ApplicationRecord
  PROVIDERS = %w[vonage sms_gateway].freeze

  belongs_to :sms_gateway, optional: true
  has_many :teams, dependent: :nullify
  has_many :messages, dependent: :nullify

  phony_normalize :phone
  validates :phone, presence: true, uniqueness: true, phony_plausible: true
  validates :provider, inclusion: { in: PROVIDERS }
  validates :sms_gateway, presence: true, if: :sms_gateway_provider?
  # Backed by a partial unique index for race safety.
  validates :default, uniqueness: true, if: :default?

  def self.default_line
    find_by(default: true)
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
end
