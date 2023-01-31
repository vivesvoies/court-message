require "test_helper"

class InboundMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in @user
  end

  test "should accept POST requests" do
    assert_difference(["Conversation.count", "Message.count", "Contact.count"]) do
      post inbound_messages_path, params: { to: fake_number, from: fake_number, text: "abc" }
    end

    assert_response :success
  end

  test "should refuse POST requests without required params" do
    assert_raise(ActionController::ParameterMissing) do
      post inbound_messages_path, params: { "content": "hello" }
    end
  end
end
