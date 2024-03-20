require "test_helper"

class InboundMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_strategy = :transaction
    @user = create(:user)
    @contact = create(:contact)
    sign_in @user
  end

  test "should accept POST requests" do
    DatabaseCleaner.strategy = :truncation

    assert_difference([ "Message.count" ]) do
      post inbound_messages_path, params: { to: fake_number, from: @contact.phone, text: "abc" }
    end

    assert_response :success
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end

  test "should refuse POST requests from unknown numbers" do
    DatabaseCleaner.strategy = :truncation

    post inbound_messages_path, params: { to: fake_number, from: fake_number, text: "abc" }
    assert_response :bad_request
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end

  test "should refuse POST requests without required params" do
    DatabaseCleaner.strategy = :truncation

    assert_raise(ActionController::ParameterMissing) do
      post inbound_messages_path, params: { content: "hello" }
    end
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end

  test "should mark conversation as unread" do
    DatabaseCleaner.strategy = :truncation

    contact = create(:contact, :with_conversation)
    conversation = contact.conversation
    assert conversation.read?

    post inbound_messages_path, params: { to: fake_number, from: contact.phone, text: "abc" }
    assert conversation.reload.unread?
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end

  test "should set Conversation#last_message on create" do
    DatabaseCleaner.strategy = :truncation
    post inbound_messages_path, params: { to: fake_number, from: @contact.phone, text: "def" }

    assert_equal "def", @contact.conversation.last_message.content
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end
end
