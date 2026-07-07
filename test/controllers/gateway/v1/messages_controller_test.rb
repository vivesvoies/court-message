require "test_helper"

class Gateway::V1::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @gateway, @token = SmsGateway.provision!(name: "raspi-test")
    @line = create(:gateway_phone_line, sms_gateway: @gateway)
    @contact = create(:contact, :with_conversation)
    @message = create(:outbound_message, conversation: @contact.conversation, phone_line: @line,
                      outbound_uuid: SecureRandom.uuid, claimed_at: Time.current)
  end

  test "should refuse requests without a token" do
    patch gateway_v1_message_path(@message.outbound_uuid), params: { status: "submitted" }

    assert_response :unauthorized
    assert_equal("unsent", @message.reload.status)
  end

  test "should record the gateway's send outcome" do
    patch gateway_v1_message_path(@message.outbound_uuid), params: { status: "submitted" }, headers: auth_header

    assert_response :ok
    assert_equal("submitted", @message.reload.status)
  end

  test "should record delivery updates" do
    patch gateway_v1_message_path(@message.outbound_uuid), params: { status: "delivered" }, headers: auth_header

    assert_response :ok
    assert_equal("delivered", @message.reload.status)
  end

  test "should reject statuses outside the whitelist" do
    patch gateway_v1_message_path(@message.outbound_uuid), params: { status: "deleted" }, headers: auth_header

    assert_response :unprocessable_entity
    assert_equal("unsent", @message.reload.status)
  end

  test "should return not found for unknown messages" do
    patch gateway_v1_message_path(SecureRandom.uuid), params: { status: "submitted" }, headers: auth_header

    assert_response :not_found
  end

  test "should not touch messages belonging to another gateway" do
    other_gateway, other_token = SmsGateway.provision!(name: "raspi-other")
    create(:gateway_phone_line, sms_gateway: other_gateway)

    patch gateway_v1_message_path(@message.outbound_uuid), params: { status: "submitted" },
          headers: { "Authorization" => "Bearer #{other_token}" }

    assert_response :not_found
    assert_equal("unsent", @message.reload.status)
  end

  private

  def auth_header
    { "Authorization" => "Bearer #{@token}" }
  end
end
