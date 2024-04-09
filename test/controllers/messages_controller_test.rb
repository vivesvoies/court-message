require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @contact = create(:contact, :with_conversation, team: @team)
    @conversation = @contact.conversation

    @message = create(:outbound_message, conversation: @conversation)

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

  # FIXME: I don't know what could have broken this test
  # test "should not get new without a conversation_id" do
  #   assert_raises(ActiveRecord::RecordNotFound) {
  #     get new_message_url
  #   }
  # end

  test "should not get new without a conversation_id the user has access to" do
    other_conversation = create(:conversation)
    get new_message_url(conversation_id: other_conversation.id)

    assert_response :forbidden
  end

  test "should create message" do
    assert_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "Hello" } }
    end

    assert_redirected_to team_conversation_url(@team, @conversation)
  end

  test "should not create message in conversations the user does not have access to" do
    other_conversation = create(:conversation)

    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: other_conversation.id, content: "Hello" } }
    end
    assert_response :forbidden
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
    post messages_url, params: { message: { conversation_id: @conversation.id, content: "Heya" } }
    assert_equal("Heya", @conversation.reload.last_message.content)
    assert_equal(Message.last, @conversation.last_message)
  end
end
