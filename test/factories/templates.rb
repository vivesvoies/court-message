# == Schema Information
#
# Table name: templates
#
#  id         :bigint           not null, primary key
#  content    :text
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint
#  user_id    :bigint
#
# Indexes
#
#  index_templates_on_team_id  (team_id)
#  index_templates_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#

FactoryBot.define do
  factory :template do
    title { Faker::TvShows::BojackHorseman.tongue_twister }
    content { Faker::TvShows::BojackHorseman.quote }
    user

    trait :shared do
      team { user.teams.first || association(:team) }
    end
  end
end
