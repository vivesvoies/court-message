require "test_helper"
class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @contact = create(:contact, team: @team)
    sign_in @user
  end

  test "should get index" do
    @conversation = create(:conversation, contact: @contact)

    get team_conversations_url(@team)
    assert_response :success
    assert_select ".Conversation"
    assert_select ".Conversation__contact", text: @conversation.title
  end

  test "should show conversations in order" do
    @contact_1 = create(:contact, :with_conversation, name: "Name 1", team: @team)
    @contact_2 = create(:contact, :with_conversation, name: "Name 2", team: @team)
    @contact_3 = create(:contact, :with_conversation, name: "Name 3", team: @team)

    get team_conversations_url(@team)
    assert_select ".Conversation", count: 3
    assert_select ".Conversation:nth-of-type(1) .Conversation__contact", text: "Name 3"
    assert_select ".Conversation:nth-of-type(2) .Conversation__contact", text: "Name 2"
    assert_select ".Conversation:nth-of-type(3) .Conversation__contact", text: "Name 1"

    @contact_2.messages << create(:inbound_message, sender: @contact_2)
    get team_conversations_url(@team)
    assert_select ".Conversation", count: 3
    assert_select ".Conversation:nth-of-type(1) .Conversation__contact", text: "Name 2"
    assert_select ".Conversation:nth-of-type(2) .Conversation__contact", text: "Name 3"
    assert_select ".Conversation:nth-of-type(3) .Conversation__contact", text: "Name 1"
  end

  test "should show conversation and sidebar" do
    @conversation = create(:conversation, contact: @contact)

    get team_conversation_url(@team, @conversation)
    assert_response :success
    assert_select "#conversation_detail .ConversationDetail__title", text: @conversation.title
    assert_select "#conversation_sidebar .Conversation__contact", text: @conversation.title
  end

  test "should select current conversation" do
    create_list(:conversation, 3, contact: @contact)
    @conversation = create(:conversation, contact: @contact)

    get team_conversation_url(@team, @conversation)
    assert_select ".Conversation--active .Conversation__contact", text: @conversation.title
  end

  test "should show conversation detail without sidebar" do
    @conversation = create(:conversation, contact: @contact)

    get detail_team_conversation_url(@team, @conversation)
    assert_response :success
    assert_select "#conversation_detail .ConversationDetail__title", text: @conversation.title
    assert_select "#conversation_sidebar .Conversation__contact", false
  end

  test "should not get conversations that belong to another team" do
    @conversation = create(:conversation, contact: @contact)
    @other_conversation = create(:conversation)

    get team_conversations_url(@team)
    assert_select ".Conversation__contact", text: @conversation.title, count: 1
    assert_select ".Conversation__contact", text: @other_conversation.title, count: 0
  end
end
