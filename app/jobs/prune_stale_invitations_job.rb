# Invitations are valid for `User.invite_for` (see config/initializers/devise.rb).
# Invitees who never accept within that window are pruned so we don't keep
# unusable, unconfirmed accounts around indefinitely (see issue #134).
#
# We only ever delete users who are still safely deletable per
# User#can_be_deleted? (unconfirmed, no messages) once their team
# memberships - which every invited user has - are removed first.
class PruneStaleInvitationsJob < ApplicationJob
  queue_as :default

  def perform
    stale_invitees = User.invitation_not_accepted
      .where(invitation_created_at: ...User.invite_for.ago)

    destroyed_count = 0
    skipped_count = 0

    stale_invitees.find_each do |user|
      ActiveRecord::Base.transaction do
        user.memberships.destroy_all
        user.reload

        if user.can_be_deleted?
          user.destroy!
          destroyed_count += 1
        else
          skipped_count += 1
          Rails.logger.info("PruneStaleInvitationsJob: skipped user ##{user.id} (not safe to delete)")
        end
      end
    end

    Rails.logger.info("PruneStaleInvitationsJob: destroyed #{destroyed_count}, skipped #{skipped_count} stale invitee(s)")
  end
end
