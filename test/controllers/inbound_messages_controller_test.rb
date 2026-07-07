require "test_helper"
require_relative "../support/vonage_webhook_signing"

class InboundMessagesControllerTest < ActionDispatch::IntegrationTest
  include VonageWebhookSigning

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

  test "should accept correctly signed requests when a signature secret is configured" do
    DatabaseCleaner.strategy = :truncation

    with_signature_secret do
      body = { to: fake_number, from: @contact.phone, text: "signed" }.to_json

      assert_difference([ "Message.count" ]) do
        post inbound_messages_path, params: body, headers: signed_webhook_headers(body)
      end
      assert_response :created
    end
  ensure
    DatabaseCleaner.strategy = @previous_strategy
  end

  test "should refuse unsigned requests when a signature secret is configured" do
    with_signature_secret do
      assert_no_difference([ "Message.count" ]) do
        post inbound_messages_path, params: { to: fake_number, from: @contact.phone, text: "abc" }
      end
      assert_response :unauthorized
    end
  end

  test "should refuse requests signed with the wrong secret" do
    with_signature_secret do
      body = { to: fake_number, from: @contact.phone, text: "abc" }.to_json

      post inbound_messages_path, params: body, headers: signed_webhook_headers(body, secret: "wrong-secret")
      assert_response :unauthorized
    end
  end

  test "should refuse requests whose payload does not match the signed payload_hash" do
    with_signature_secret do
      body = { to: fake_number, from: @contact.phone, text: "tampered" }.to_json
      other_hash = Digest::SHA256.hexdigest("something else")

      post inbound_messages_path, params: body, headers: signed_webhook_headers(body, payload_hash: other_hash)
      assert_response :unauthorized
    end
  end
end
