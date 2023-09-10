require "test_helper"

class InboundMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @contact = create(:contact)
    sign_in @user
  end

  test "should accept POST requests" do
    assert_difference(["Message.count"]) do
      post inbound_messages_path, params: { to: fake_number, from: @contact.phone, text: "abc" }
    end

    assert_response :success
  end

  test "should refuse POST requests from unknown numbers" do
    post inbound_messages_path, params: { to: fake_number, from: fake_number, text: "abc" }
    assert_response :bad_request
  end

  test "should refuse POST requests without required params" do
    assert_raise(ActionController::ParameterMissing) do
      post inbound_messages_path, params: { "content": "hello" }
    end
  end

  test "should mark conversation as unread" do
    contact = create(:contact, :with_conversation)
    conversation = contact.conversation
    assert conversation.read?

    post inbound_messages_path, params: { to: fake_number, from: contact.phone, text: "abc" }
    assert conversation.reload.unread?
  end
end
