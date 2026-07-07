require "test_helper"

class Gateway::V1::MessageClaimsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @gateway, @token = SmsGateway.provision!(name: "raspi-test")
    @line = create(:gateway_phone_line, sms_gateway: @gateway)
    @contact = create(:contact, :with_conversation)
    @conversation = @contact.conversation
  end

  test "should refuse requests without a token" do
    post gateway_v1_message_claims_path

    assert_response :unauthorized
  end

  test "should refuse requests with a wrong token" do
    post gateway_v1_message_claims_path, headers: { "Authorization" => "Bearer wrong-token" }

    assert_response :unauthorized
  end

  test "should claim queued messages for the gateway's lines" do
    message = create(:outbound_message, conversation: @conversation, phone_line: @line, outbound_uuid: SecureRandom.uuid)

    post gateway_v1_message_claims_path, headers: auth_header

    assert_response :success
    payload = response.parsed_body
    assert_equal(1, payload["messages"].size)
    assert_equal(message.outbound_uuid, payload["messages"].first["uuid"])
    assert_equal(@contact.phone, payload["messages"].first["to"])
    assert_equal(@line.phone, payload["messages"].first["from"])
    assert_equal(message.content, payload["messages"].first["content"])
    assert(message.reload.claimed_at.present?)
  end

  test "should not claim the same message twice" do
    create(:outbound_message, conversation: @conversation, phone_line: @line, outbound_uuid: SecureRandom.uuid)

    post gateway_v1_message_claims_path, headers: auth_header
    assert_equal(1, response.parsed_body["messages"].size)

    post gateway_v1_message_claims_path, headers: auth_header
    assert_empty(response.parsed_body["messages"])
  end

  test "should not claim messages belonging to another gateway" do
    other_gateway, _token = SmsGateway.provision!(name: "raspi-other")
    other_line = create(:gateway_phone_line, sms_gateway: other_gateway)
    create(:outbound_message, conversation: @conversation, phone_line: other_line, outbound_uuid: SecureRandom.uuid)

    post gateway_v1_message_claims_path, headers: auth_header

    assert_empty(response.parsed_body["messages"])
  end

  test "should only claim messages of the given line when phone is passed" do
    other_line = create(:gateway_phone_line, sms_gateway: @gateway)
    mine = create(:outbound_message, conversation: @conversation, phone_line: @line, outbound_uuid: SecureRandom.uuid)
    create(:outbound_message, conversation: @conversation, phone_line: other_line, outbound_uuid: SecureRandom.uuid)

    post gateway_v1_message_claims_path, params: { phone: @line.phone }, headers: auth_header

    payload = response.parsed_body
    assert_equal([ mine.outbound_uuid ], payload["messages"].map { |m| m["uuid"] })
  end

  test "should update the gateway's last_seen_at" do
    post gateway_v1_message_claims_path, headers: auth_header

    assert(@gateway.reload.last_seen_at.present?)
  end

  private

  def auth_header
    { "Authorization" => "Bearer #{@token}" }
  end
end
