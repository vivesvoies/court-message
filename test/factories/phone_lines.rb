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
FactoryBot.define do
  factory :phone_line do
    phone { Faker::PhoneNumber.cell_phone_in_e164 }
    provider { "vonage" }

    factory :gateway_phone_line do
      provider { "sms_gateway" }
      sms_gateway
    end
  end
end
