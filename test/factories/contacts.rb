# == Schema Information
#
# Table name: contacts
#
#  id                   :bigint           not null, primary key
#  email                :string
#  name                 :string
#  notes                :text
#  notes_updated_at     :datetime
#  phone                :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  created_by_id        :bigint
#  notes_last_editor_id :bigint
#  team_id              :bigint           not null
#
# Indexes
#
#  index_contacts_on_created_by_id         (created_by_id)
#  index_contacts_on_notes_last_editor_id  (notes_last_editor_id)
#  index_contacts_on_phone                 (phone)
#  index_contacts_on_team_id               (team_id)
#  index_contacts_on_team_id_and_phone     (team_id,phone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (notes_last_editor_id => users.id)
#  fk_rails_...  (team_id => teams.id)
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
