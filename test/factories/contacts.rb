# == Schema Information
#
# Table name: contacts
#
#  id                   :integer          not null, primary key
#  name                 :string
#  email                :string
#  phone                :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  team_id              :integer          not null
#  notes                :text
#  notes_updated_at     :datetime
#  notes_last_editor_id :integer
#  created_by_id        :integer
#
# Indexes
#
#  index_contacts_on_created_by_id         (created_by_id)
#  index_contacts_on_notes_last_editor_id  (notes_last_editor_id)
#  index_contacts_on_phone                 (phone)
#  index_contacts_on_team_id               (team_id)
#  index_contacts_on_team_id_and_phone     (team_id,phone) UNIQUE
#

FactoryBot.define do
  factory :contact do
    email { Faker::Internet.email }
    name { Faker::Name.name }
    phone { Faker::PhoneNumber.cell_phone_in_e164 }
    team

    trait :with_conversation do
      conversation
    end
  end
end
