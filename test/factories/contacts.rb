FactoryBot.define do
  factory :contact do
    email { Faker::Internet.email }
    name { Faker::Name.name }
    phone { Faker::PhoneNumber.cell_phone_in_e164 }
    # conversation
  end
end
