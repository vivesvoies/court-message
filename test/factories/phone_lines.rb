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
#  index_phone_lines_on_fallback_phone_line_id  (fallback_phone_line_id)
#  index_phone_lines_on_phone                   (phone) UNIQUE
#  index_phone_lines_on_single_default          (default) UNIQUE WHERE ("default" = true)
#  index_phone_lines_on_sms_gateway_id          (sms_gateway_id)
#
# Foreign Keys
#
#  fk_rails_...  (fallback_phone_line_id => phone_lines.id)
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
