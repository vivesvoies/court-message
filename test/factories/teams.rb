# == Schema Information
#
# Table name: teams
#
#  id            :bigint           not null, primary key
#  address       :text
#  desc          :text
#  name          :text             not null
#  slug          :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  phone_line_id :bigint
#
# Indexes
#
#  index_teams_on_name           (name) UNIQUE
#  index_teams_on_phone_line_id  (phone_line_id)
#  index_teams_on_slug           (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (phone_line_id => phone_lines.id)
#

FactoryBot.define do
  factory :team do
    sequence(:name) { |n| "#{Faker::Company.name} #{n}" }
    slug { name.parameterize }
    address { "Address" }
    desc { "Description" }
  end
end
