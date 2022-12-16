require "test_helper"

class InboundMessagesControllerTest < ActionDispatch::IntegrationTest
  test "should accept POST requests" do

    assert_difference(["Conversation.count", "Message.count", "Contact.count"]) do
      post inbound_messages_path, params: { to: Faker::PhoneNumber.cell_phone_in_e164, from: "12345", text: "abc" }
    end

    assert_response :success
  end

  test "should refuse POST requests without required params" do
    assert_raise(ActionController::ParameterMissing) do
      post inbound_messages_path, params: { "content": "hello" }
    end
  end
end
