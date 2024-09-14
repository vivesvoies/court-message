require "test_helper"

class OutboundMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @contact = create(:contact, :with_conversation, team: @team)
    @conversation = @contact.conversation

    @message = create(:outbound_message, conversation: @conversation, outbound_uuid: SecureRandom.uuid, status: :submitted)
  end

  test "should update message status" do
    post outbound_messages_path, params: { message_uuid: @message.outbound_uuid, status: "delivered" }
    assert_response :ok
    assert_equal "delivered", @message.reload.status
  end

  test "should return too early if message is not found" do
    post outbound_messages_path, params: { message_uuid: SecureRandom.uuid, status: "delivered" }
    assert_response :too_early
  end

  test "should return too early if message_uuid is missing" do
    post outbound_messages_path, params: { status: "delivered" }
    assert_response :too_early
  end

  test "should handle failed outbound message submission" do
    post outbound_messages_path, params: { message_uuid: @message.outbound_uuid, status: "failed" }

    assert_equal "failed", @message.reload.status
    assert_response :ok
  end
end
