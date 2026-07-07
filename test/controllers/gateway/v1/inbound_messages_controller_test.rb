require "test_helper"

class Gateway::V1::InboundMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_strategy = :transaction
    @gateway, @token = SmsGateway.provision!(name: "raspi-test")
    @line = create(:gateway_phone_line, sms_gateway: @gateway)
    @contact = create(:contact)
  end

  test "should refuse requests without a token" do
    post gateway_v1_inbound_messages_path, params: { from: @contact.phone, text: "abc" }

    assert_response :unauthorized
  end

  test "should accept SMS received by the gateway" do
    DatabaseCleaner.strategy = :truncation

    assert_difference([ "Message.count" ]) do
      post gateway_v1_inbound_messages_path, params: { to: @line.phone, from: @contact.phone, text: "abc" },
           headers: auth_header
    end

    assert_response :created
    message = Message.last
    assert(message.inbound_status?)
    assert_equal(@line, message.phone_line)
    assert_equal("raspi-test", message.provider_info["sms_gateway"])
    assert(@contact.conversation.reload.unread?)
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end

  test "should accept SMS without a to number" do
    DatabaseCleaner.strategy = :truncation

    post gateway_v1_inbound_messages_path, params: { from: @contact.phone, text: "abc" }, headers: auth_header

    assert_response :created
    assert_nil(Message.last.phone_line)
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end

  test "should not create duplicates when the gateway retries a delivered SMS" do
    DatabaseCleaner.strategy = :truncation
    params = { to: @line.phone, from: @contact.phone, text: "abc", modem_message_id: "cafe1234" }

    post gateway_v1_inbound_messages_path, params:, headers: auth_header
    assert_response :created

    assert_no_difference([ "Message.count" ]) do
      post gateway_v1_inbound_messages_path, params:, headers: auth_header
    end
    assert_response :created
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end

  test "should refuse SMS from unknown numbers" do
    post gateway_v1_inbound_messages_path, params: { to: @line.phone, from: fake_number, text: "abc" },
         headers: auth_header

    assert_response :unprocessable_entity
  end

  test "should refuse SMS without required params" do
    assert_raise(ActionController::ParameterMissing) do
      post gateway_v1_inbound_messages_path, params: { content: "hello" }, headers: auth_header
    end
  end

  private

  def auth_header
    { "Authorization" => "Bearer #{@token}" }
  end
end
