# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_memberships_on_team_id              (team_id)
#  index_memberships_on_team_id_and_user_id  (team_id,user_id) UNIQUE
#  index_memberships_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#

require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  def test_delegation
    m = create(:membership)
    assert_equal(m.user.identifier, m.identifier)
  end

  def test_uniqueness_constraint
    user = create(:user)
    team = create(:team)
    m = create(:membership, team:, user:)
    assert_raise(ActiveRecord::RecordNotUnique) {
      create(:membership, team:, user:)
    }
  end
end
