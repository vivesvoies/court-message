# == Schema Information
#
# Table name: teams
#
#  id         :bigint           not null, primary key
#  address    :text
#  desc       :text
#  name       :text             not null
#  slug       :text             not null
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
