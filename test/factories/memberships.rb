# == Schema Information
#
# Table name: memberships
#
#  id         :integer          not null, primary key
#  team_id    :integer          not null
#  user_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_memberships_on_team_id              (team_id)
#  index_memberships_on_team_id_and_user_id  (team_id,user_id) UNIQUE
#  index_memberships_on_user_id              (user_id)
#

FactoryBot.define do
  factory :membership do
    team
    user
  end
end
