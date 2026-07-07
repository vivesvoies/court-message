# == Schema Information
#
# Table name: teams
#
#  id              :bigint           not null, primary key
#  address         :text
#  desc            :text
#  name            :text             not null
#  slug            :text             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  phone_number_id :bigint
#
# Indexes
#
#  index_teams_on_name             (name) UNIQUE
#  index_teams_on_phone_number_id  (phone_number_id)
#  index_teams_on_slug             (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (phone_number_id => phone_numbers.id)
#

require "test_helper"

class TeamTest < ActiveSupport::TestCase
  def test_factory_is_valid
    t = create(:team)
    assert(t.valid?)
  end

  def test_name_required
    name = ""
    t = build(:team, name:)
    assert_raise(ActiveRecord::RecordInvalid) {
      t.save!
    }
  end

  def test_auto_slug
    name = "A Team"
    t = create(:team, name:)
    assert_equal(name.parameterize, t.slug)
  end

  def test_slugs_and_names_uniqueness
    name = "Another Team"
    create(:team, name:)
    assert_raise(ActiveRecord::RecordInvalid) {
      create(:team, name:)
    }
  end

  def test_team_has_members
    t = create(:team)
    users = create_list(:user, 3)
    t.users = users
    t.save

    assert_equal(3, t.users.count)
  end

  def test_team_destroys_memberships
    users = create_list(:user, 3)
    t = create(:team, users:)

    assert_difference "Membership.count", -3 do
      t.destroy
    end
  end

  def test_delegates_include_to_users
    user = create(:user)
    other_user = create(:user)
    team = user.teams.first

    assert(user.in? team)
    assert(team.include? user)
    assert_not(other_user.in? team)
    assert_not(team.include? other_user)
  end

  def test_outbound_number_uses_assigned_phone_number
    number = create(:phone_number, number: "33612345678")
    team = create(:team, phone_number: number)

    assert_equal("33612345678", team.outbound_number)
  end

  def test_outbound_number_falls_back_to_configured_number
    team = create(:team)

    assert_nil(team.phone_number)
    assert_equal(Rails.configuration.x.outbound_phone_number, team.outbound_number)
  end
end
