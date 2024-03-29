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
#  invitation_accepted_at :datetime
#  invitation_created_at  :datetime
#  invitation_limit       :integer
#  invitation_sent_at     :datetime
#  invitation_token       :string
#  invitations_count      :integer          default(0)
#  invited_by_type        :string
#  name                   :string
#  phone                  :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :enum             default("user"), not null
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  invited_by_id          :bigint
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_invitation_token      (invitation_token) UNIQUE
#  index_users_on_invited_by            (invited_by_type,invited_by_id)
#  index_users_on_invited_by_id         (invited_by_id)
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

  def test_awaiting_invitation_reply
    user_without_invitation = create(:user)
    assert_not(user_without_invitation.awaiting_invitation_reply?)

    user_with_confirmed_at = create(:user, confirmed_at: Time.now)
    assert_not(user_with_confirmed_at.awaiting_invitation_reply?)

    user_with_invitation = create(:user, invitation_created_at: Time.now)
    assert(user_with_invitation.awaiting_invitation_reply?)

    user_with_invitation_and_confirmed_at = create(:user, confirmed_at: Time.now - 1, invitation_created_at: Time.now)
    assert(user_with_invitation.awaiting_invitation_reply?)

    user_with_accepted_invitation = create(:user, invitation_created_at: Time.now, invitation_accepted_at: Time.now)
    assert_not(user_with_accepted_invitation.awaiting_invitation_reply?)
  end

  def test_can_be_deleted
    user = create(:user)
    user.update(teams: [], messages: [], confirmed_at: nil)
    assert(user.can_be_deleted?)

    user = create(:user)
    assert_not(user.can_be_deleted?)

    user = create(:user, confirmed_at: Time.now)
    assert_not(user.can_be_deleted?)

    user = create(:user)
    team = create(:team)
    user.teams << team
    assert_not(user.can_be_deleted?)

    user = create(:user)
    new_message = Message.new({ content: "...", status: "unsent", sender_id: user.id })
    assert_not(user.can_be_deleted?)
  end
end
