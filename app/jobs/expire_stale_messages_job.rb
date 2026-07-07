# The provider does not always deliver a terminal status callback: a message
# can stay "submitted" forever (see issue #248, "Absent Subscriber"). Vonage
# gives up delivery after ~48-72h, so anything still "submitted" after that
# window is expired on our side too, and the sender sees the failure.
class ExpireStaleMessagesJob < ApplicationJob
  queue_as :default

  STALE_AFTER = 72.hours

  def perform
    stale = Message.submitted_status.where(updated_at: ...STALE_AFTER.ago)
    count = stale.count
    return if count.zero?

    stale.find_each { |message| message.update!(status: :expired) }
    Rails.logger.info("ExpireStaleMessagesJob expired #{count} stale submitted message(s)")
  end
end
