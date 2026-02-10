require "test_helper"
class ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @contact = create(:contact, team: @team)
    sign_in @user
  end

  # Pagination

  test "should paginate conversations" do
    create_conversations(30)

    get team_conversations_url(@team)
    assert_response :success
    assert_select ".Conversation", count: ConversationsController::PAGE_SIZE
  end

  test "should load next page of conversations" do
    create_conversations(30)

    get team_conversations_url(@team, page: 2)
    assert_response :success
    assert_select ".Conversation", count: 30 - ConversationsController::PAGE_SIZE
  end

  test "should not show load more link on last page" do
    create_conversations(3)

    get team_conversations_url(@team)
    assert_response :success
    assert_select "turbo-frame#next_page", false
  end

  test "should show load more link when there are more conversations" do
    create_conversations(30)

    get team_conversations_url(@team)
    assert_response :success
    assert_select "turbo-frame#next_page"
  end

  test "should paginate my conversations" do
    conversations = create_conversations(30)
    conversations.each { |c| c.agents << @user }

    get team_conversations_url(@team, show: "mine")
    assert_response :success
    assert_select ".Conversation", count: ConversationsController::PAGE_SIZE
  end

  test "pages should not overlap" do
    create_conversations(30)

    get team_conversations_url(@team)
    page_1_ids = css_select(".Conversation").map { |el| el["id"] }

    get team_conversations_url(@team, page: 2)
    page_2_ids = css_select(".Conversation").map { |el| el["id"] }

    assert_empty page_1_ids & page_2_ids, "Page 1 and page 2 should not share any conversations"
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
    assert_select "#conversation_detail .ConversationDetail__title", match: "À : " + @conversation.title
    assert_select "#conversations .Conversation__contact", text: @conversation.title
  end

  test "should select current conversation" do
    create_list(:conversation, 3, contact: @contact)
    @conversation = create(:conversation, contact: @contact)

    get team_conversation_url(@team, @conversation)
    assert_select ".Conversation--active .Conversation__contact", text: @conversation.title
  end

  test "should select conversation marked as :selected" do
    create_list(:conversation, 3, contact: @contact)
    @conversation = create(:conversation, contact: @contact)

    get team_conversations_url(@team, selected: @conversation.id)
    assert_select ".Conversation--active .Conversation__contact", text: @conversation.title
  end

  # TODO: conversation_detail could be delete
  # test "should show conversation detail without sidebar" do
  #   @conversation = create(:conversation, contact: @contact)

  #   get detail_team_conversation_url(@team, @conversation)
  #   assert_response :success
  #   assert_select "#conversation_detail .ConversationDetail__title", text: @conversation.title
  #   assert_select "#conversations .Conversation__contact", false
  # end

  test "should not get conversations that belong to another team" do
    @conversation = create(:conversation, contact: @contact)
    @other_conversation = create(:conversation)

    get team_conversations_url(@team)
    assert_select ".Conversation__contact", text: @conversation.title, count: 1
    assert_select ".Conversation__contact", text: @other_conversation.title, count: 0
  end

  test "should not access the conversations of other teams" do
    @other_team = create(:team)
    @other_contact = create(:contact, :with_conversation, team: @other_team)

    get team_conversations_url(@other_team)
    assert_response :forbidden

    get team_conversation_url(@other_team, @other_contact.conversation)
    assert_response :forbidden

    assert_select ".Conversation__contact", text: @other_contact.identifier, count: 0
  end

  private

  def create_conversations(count)
    count.times.map do |i|
      contact = create(:contact, team: @team, phone: "+3360000#{i.to_s.rjust(4, '0')}")
      create(:conversation, contact: contact)
    end
  end
end
