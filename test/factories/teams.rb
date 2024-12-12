# == Schema Information
#
# Table name: teams
#
#  id         :integer          not null, primary key
#  name       :text             not null
#  slug       :text             not null
#  address    :text
#  desc       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_teams_on_name  (name) UNIQUE
#  index_teams_on_slug  (slug) UNIQUE
#

FactoryBot.define do
  factory :team do
    name { Faker::Company.name }
    slug { name.parameterize }
    address { "Address" }
    desc { "Description" }
  end
end
