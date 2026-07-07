require "test_helper"

class MessageDeliveryJobTest < ActiveJob::TestCase
  setup do
    @user = create(:user)
    @conversation = create(:conversation)
    @message = Message.create!(content: "Lorem Ipsum", conversation: @conversation, sender: @user)
  end

  test "submits the message to the provider" do
    MessageDeliveryJob.perform_now(@message)

    assert @message.reload.submitted_status?
    assert_not_nil @message.outbound_uuid
  end

  test "does nothing when the message is no longer unsent" do
    @message.update!(status: :delivered)

    MessageDeliveryJob.perform_now(@message)

    assert @message.reload.delivered_status?
    assert_nil @message.outbound_uuid
  end

  test "retries on delivery errors and marks the message failed once exhausted" do
    raising_service = Object.new
    def raising_service.submit! = raise OutboundMessagesService::DeliveryError, "provider down"

    performed = 0
    counting_service = ->(*) { performed += 1; raising_service }

    OutboundMessagesService.stub(:new, counting_service) do
      perform_enqueued_jobs do
        MessageDeliveryJob.perform_later(@message)
      end
    end

    assert_equal 5, performed, "should attempt delivery 5 times before giving up"
    assert @message.reload.failed_status?
  end
end
