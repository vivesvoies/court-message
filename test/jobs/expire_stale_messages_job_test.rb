require "test_helper"

class ExpireStaleMessagesJobTest < ActiveJob::TestCase
  setup do
    @user = create(:user)
    @conversation = create(:conversation)
  end

  test "expires messages stuck in submitted beyond the stale window" do
    stale = create_submitted_message(updated_at: 4.days.ago)
    fresh = create_submitted_message(updated_at: 1.hour.ago)
    delivered = create_submitted_message(updated_at: 4.days.ago, status: :delivered)

    ExpireStaleMessagesJob.perform_now

    assert stale.reload.expired_status?
    assert fresh.reload.submitted_status?
    assert delivered.reload.delivered_status?
  end

  private

  def create_submitted_message(updated_at:, status: :submitted)
    message = Message.create!(content: "Lorem", conversation: @conversation, sender: @user, status:)
    message.update_columns(updated_at:)
    message
  end
end
