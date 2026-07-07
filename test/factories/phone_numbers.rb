# == Schema Information
#
# Table name: phone_numbers
#
#  id         :bigint           not null, primary key
#  label      :string
#  number     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_phone_numbers_on_number  (number) UNIQUE
#

FactoryBot.define do
  factory :phone_number do
    sequence(:number) { |n| "3364463#{format('%04d', n)}" }
    label { "Numéro d'équipe" }
  end
end
