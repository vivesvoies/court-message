# == Schema Information
#
# Table name: templates
#
#  id         :bigint           not null, primary key
#  content    :text
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_templates_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

FactoryBot.define do
  factory :template do
    title { Faker::TvShows::BojackHorseman.tongue_twister }
    content { Faker::TvShows::BojackHorseman.quote }
    user
  end
end
