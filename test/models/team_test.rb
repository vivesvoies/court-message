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
require "test_helper"

class TeamTest < ActiveSupport::TestCase
  def test_factory_is_valid
    t = create(:team)
    assert(t.valid?)
  end

  def test_auto_slug
    name = "My Team"
    t = create(:team, name:)
    assert_equal(name.parameterize, t.slug)
  end

  def test_slugs_and_names_uniqueness
    name = "My Team"
    t = create(:team, name:)
    t2 = build(:team, name:)

    assert(!t2.valid?)
  end

  def test_team_has_members
    t = create(:team)
    users = create_list(:user, 3)
    t.users = users
    t.save

    assert_equal(3, t.users.count)
  end
end
