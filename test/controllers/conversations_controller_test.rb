require "test_helper"
class ConversationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    @conversation = create(:conversation)

    get conversations_url
    assert_response :success
    assert_select ".Conversation"
    assert_select ".Conversation__contact", text: @conversation.title
  end

  test "should show conversation" do
    @conversation = create(:conversation)

    get conversation_url(@conversation)
    assert_response :success
    assert_select ".ConversationDetail__title", text: @conversation.title
  end
end
