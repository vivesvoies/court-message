require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @contact = create(:contact, :with_conversation, team: @team)
    @conversation = @contact.conversation

    @message = create(:outbound_message, conversation: @conversation)

    Current.phone_number = "33644630057"

    @expected_uuid = SecureRandom.uuid

    @provider_success = Minitest::Mock.new
    @provider_success.expect(
      :send,
      OpenStruct.new(message_uuid: @expected_uuid, http_response: Net::HTTPSuccess.new(1.0, "200", "OK")),
      from: Current.phone_number, to: @conversation.contact.phone, content: @message.content
    )

    sign_in(@user)
  end

  test "should not get index" do
    assert_raises(ActionController::RoutingError) {
      get messages_url
    }
  end

  test "should get new" do
    get new_message_url(conversation_id: @conversation.id)
    assert_response :success
  end

  test "should not get new without a conversation_id" do
    assert_raises(ActiveRecord::RecordNotFound) {
      get new_message_url
    }
  end

  test "should not get new without a conversation_id the user has access to" do
    other_conversation = create(:conversation)
    get new_message_url(conversation_id: other_conversation.id)

    assert_response :forbidden
  end

  test "should create message" do
    OutboundMessagesService.stub(:new, OutboundMessagesService.new(@message, @provider_success)) do
      assert_difference("Message.count", 1) do
        post messages_url, params: { message: { conversation_id: @conversation.id, content: @message.content } }
      end

      assert_redirected_to team_conversation_url(@team, @conversation)
    end

    @provider_success.verify
  end

  test "should not create message in conversations the user does not have access to" do
    other_conversation = create(:conversation)

    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: other_conversation.id, content: "Hello" } }
    end
    assert_response :forbidden
  end

  test "should not create message with blank content" do
    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "" } }
    end

    assert_response :unprocessable_entity
    assert_match /Le contenu du message ne peut être vide/, flash[:notice]
  end

  test "should not create message with only spaces" do
    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "   " } }
    end

    assert_response :unprocessable_entity
    assert_match /Le contenu du message ne peut être vide/, flash[:notice]
  end

  test "should not create message with only tabs" do
    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "\t\t\t" } }
    end

    assert_response :unprocessable_entity
    assert_match /Le contenu du message ne peut être vide/, flash[:notice]
  end

  test "should not show message" do
    assert_raises(NoMethodError) {
      get message_url(@message)
    }
  end

  test "should not get edit" do
    assert_raises(NoMethodError) {
      get edit_message_url(@message)
    }
  end

  test "should not update message" do
    # See OutboundMessagesControllerTest for message status update tests
    assert_raises(NoMethodError) {
      patch message_url(@message), params: { message: {} }
    }
  end

  test "should not destroy message" do
    assert_raises(NoMethodError) {
      delete message_url(@message)
    }
  end

  test "should set Conversation#last_message on create" do
    OutboundMessagesService.stub(:new, OutboundMessagesService.new(@message, @provider_success)) do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "Heya" } }
      assert_equal("Heya", @conversation.reload.last_message.content)
      assert_equal(Message.last, @conversation.last_message)

      assert_redirected_to team_conversation_url(@team, @conversation)
    end

    @provider_success.verify
  end

  test "should associate message with conversation and update last_message" do
    OutboundMessagesService.stub(:new, OutboundMessagesService.new(@message, @provider_success)) do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "Test message" } }

      assert_equal("Test message", @conversation.reload.last_message.content)
      assert_equal(Message.last, @conversation.last_message)
    end

    @provider_success.verify
  end

  test "should create message if provider fails" do
    @provider_fail = Minitest::Mock.new

    @provider_fail.expect(
      :send,
      OpenStruct.new(message_uuid: @expected_uuid, http_response: Net::HTTPServiceUnavailable.new(1.1, "503", "Service Unavailable")),
      from: Current.phone_number, to: @conversation.contact.phone, content: @message.content
    )

    OutboundMessagesService.stub(:new, OutboundMessagesService.new(@message, @provider_fail)) do
      assert_difference("Message.count", 1) do
        post messages_url, params: { message: { conversation_id: @conversation.id, content: @message.content } }
      end

      assert_response :unprocessable_entity
    end

    @provider_fail.verify
  end

  test "should handle failed outbound message submission" do
    post outbound_messages_path, params: { message_uuid: @message.outbound_uuid, status: "failed" }

    assert_equal "failed", @message.reload.status
    assert_response :ok
  end
end
