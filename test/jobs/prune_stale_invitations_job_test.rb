require "test_helper"

class PruneStaleInvitationsJobTest < ActiveJob::TestCase
  setup do
    @team = create(:team)
  end

  test "destroys an unaccepted invitee and their membership once the invitation is older than invite_for" do
    user = invite_user(email: "stale@example.com", created_at: 11.days.ago)

    PruneStaleInvitationsJob.perform_now

    assert_nil User.find_by(id: user.id)
    assert_nil Membership.find_by(user_id: user.id)
  end

  test "keeps an unaccepted invitee whose invitation is still within the validity window" do
    user = invite_user(email: "fresh@example.com", created_at: 5.days.ago)

    PruneStaleInvitationsJob.perform_now

    assert User.exists?(user.id)
    assert Membership.exists?(user_id: user.id)
  end

  test "keeps an invitee who already accepted their invitation, even if it was sent long ago" do
    user = invite_user(email: "accepted@example.com", created_at: 11.days.ago)
    user.update_columns(
      invitation_accepted_at: 10.days.ago,
      invitation_token: nil,
      confirmed_at: 10.days.ago
    )

    PruneStaleInvitationsJob.perform_now

    assert User.exists?(user.id)
    assert Membership.exists?(user_id: user.id)
  end

  test "keeps a stale unaccepted invitee who somehow already has messages" do
    user = invite_user(email: "has-messages@example.com", created_at: 11.days.ago)
    conversation = create(:conversation)
    create(:outbound_message, sender: user, conversation: conversation)

    PruneStaleInvitationsJob.perform_now

    # The user is never deleted since they have messages, even though their
    # (now redundant) team membership is cleaned up along the way.
    assert User.exists?(user.id)
  end

  private

  def invite_user(email:, created_at:)
    user = User.invite!(email: email, name: "Invitee") do |u|
      u.skip_invitation = true
      u.invited_by_id = create(:user).id
    end
    user.update_columns(invitation_created_at: created_at, invitation_sent_at: created_at)
    Membership.create!(team: @team, user: user)
    user
  end
end
