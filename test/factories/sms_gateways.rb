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
FactoryBot.define do
  factory :sms_gateway do
    sequence(:name) { |n| "raspi-#{n}" }
    token_digest { SmsGateway.digest(SecureRandom.base58(32)) }
  end
end
