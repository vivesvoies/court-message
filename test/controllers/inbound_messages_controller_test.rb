require "test_helper"

class InboundMessagesControllerTest < ActionDispatch::IntegrationTest
  test "should accept POST requests" do
    post inbound_messages_path, params: { to: "12345", from: "12345", text: "abc"}
    assert_response :success
  end

  test "should refuse POST requests without required params" do
    assert_raise(ActionController::ParameterMissing) do
      post inbound_messages_path, params: { "content": "hello" }
    end
  end
end
