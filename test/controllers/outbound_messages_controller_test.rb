require "test_helper"
require_relative "../support/vonage_webhook_signing"

class OutboundMessagesControllerTest < ActionDispatch::IntegrationTest
  include VonageWebhookSigning

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

  test "should refuse unknown statuses" do
    post outbound_messages_path, params: { message_uuid: @message.outbound_uuid, status: "bogus" }

    assert_response :unprocessable_entity
    assert_equal "submitted", @message.reload.status
  end

  test "should refuse internal statuses" do
    %w[inbound unsent deleted].each do |status|
      post outbound_messages_path, params: { message_uuid: @message.outbound_uuid, status: }

      assert_response :unprocessable_entity
      assert_equal "submitted", @message.reload.status
    end
  end

  test "should accept correctly signed requests when a signature secret is configured" do
    with_signature_secret do
      body = { message_uuid: @message.outbound_uuid, status: "delivered" }.to_json

      post outbound_messages_path, params: body, headers: signed_webhook_headers(body)
      assert_response :ok
      assert_equal "delivered", @message.reload.status
    end
  end

  test "should refuse unsigned requests when a signature secret is configured" do
    with_signature_secret do
      post outbound_messages_path, params: { message_uuid: @message.outbound_uuid, status: "delivered" }

      assert_response :unauthorized
      assert_equal "submitted", @message.reload.status
    end
  end
end
