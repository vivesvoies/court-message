# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string
#  phone                  :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :enum             default("user"), not null
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
require "test_helper"

class UserTest < ActiveSupport::TestCase
  def test_memberships
    teams = create_list(:team, 3)
    user = create(:user, teams:)

    assert(user.valid?)
    assert_equal(user.teams.count, 3)
  end

  def test_at_least
    user = create(:user)
    assert(user.at_least?(:user))
    assert_not(user.at_least?(:team_admin))
    assert_not(user.at_least?(:site_admin))
    assert_not(user.at_least?(:super_admin))

    team_admin = create(:user, role: :team_admin)
    assert(team_admin.at_least?(:user))
    assert(team_admin.at_least?(:team_admin))
    assert_not(team_admin.at_least?(:site_admin))
    assert_not(team_admin.at_least?(:super_admin))

    site_admin = create(:user, role: :site_admin)
    assert(site_admin.at_least?(:user))
    assert(site_admin.at_least?(:team_admin))
    assert(site_admin.at_least?(:site_admin))
    assert_not(site_admin.at_least?(:super_admin))

    super_admin = create(:user, role: :super_admin)
    assert(super_admin.at_least?(:user))
    assert(super_admin.at_least?(:team_admin))
    assert(super_admin.at_least?(:site_admin))
    assert(super_admin.at_least?(:super_admin))
  end
end
