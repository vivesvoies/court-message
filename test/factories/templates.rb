# == Schema Information
#
# Table name: templates
#
#  id         :integer          not null, primary key
#  title      :string
#  content    :text
#  user_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_templates_on_user_id  (user_id)
#

FactoryBot.define do
  factory :template do
    title { Faker::TvShows::BojackHorseman.tongue_twister }
    content { Faker::TvShows::BojackHorseman.quote }
    user
  end
end
