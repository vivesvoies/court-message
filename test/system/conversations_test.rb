require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @team = create(:team)
    @user = create(:user, teams: [@team])

    @contact = create(:contact, team: @team)
    @conversation = create(:conversation, contact: @contact)

    @message = create(:inbound_message, conversation: @conversation)
    @conversation.messages << @message

    sign_in @user

    resize_to_desktop
  end

  test "visiting the index" do
    visit team_conversations_url(@team)
    assert_selector ".Conversation__contact", text: @conversation.contact.to_s
  end

  test "opening a conversation" do
    visit team_conversations_url(@team)
    click_on @conversation.contact.to_s, match: :first
    assert_selector ".Message__content", text: @message.content
  end

  test "loading conversation path shows sidebar" do
    visit team_conversations_url(@team)
    click_on @conversation.contact.to_s, match: :first
    sleep 0.5
    assert_equal team_conversation_url(@team, @conversation), current_url

    visit current_url
    assert_selector ".Message__content", text: @message.content
    assert_selector ".Conversation__contact", text: @conversation.contact.to_s
  end

  test "creating a new conversation" do
    contact = build(:contact)

    visit team_conversations_url(@team)
    click_on "Nouvelle conversation"
    fill_in "contact_name", with: contact.name
    fill_in "contact_phone", with: contact.phone
    fill_in "contact_email", with: contact.email
    click_on "Créer la fiche"
    sleep 0.5
    assert_no_selector "#error_explanation"
    visit team_conversations_url(@team)

    assert_selector ".Conversation__contact", text: contact.name
  end

  test "being responsive" do
    resize_to_mobile

    visit team_conversations_url(@team)
    viewer_width = page.evaluate_script('document.getElementById("viewer").getBoundingClientRect().width')
    list_width = page.evaluate_script('document.getElementById("conversation_sidebar").getBoundingClientRect().width')
    assert_equal(viewer_width, list_width)

    click_on @conversation.contact.to_s, match: :first
    sleep 0.5
    list_width = page.evaluate_script('document.getElementById("conversation_sidebar").getBoundingClientRect().width')
    conv_width = page.evaluate_script('document.getElementById("conversation_detail").getBoundingClientRect().width')
    assert_equal(0, list_width)
    assert_equal(viewer_width, conv_width)

    resize_to_desktop
    viewer_width = page.evaluate_script('document.getElementById("viewer").getBoundingClientRect().width')
    list_width = page.evaluate_script('document.getElementById("conversation_sidebar").getBoundingClientRect().width')
    conv_width = page.evaluate_script('document.getElementById("conversation_detail").getBoundingClientRect().width')
    assert(list_width > 0)
    assert(conv_width > 0)
    assert_equal(viewer_width, conv_width + list_width)
  end

  test "selecting current conversation" do
    @conversations = create_list(:conversation, 5)
    first = @conversations.first
    last = @conversations.last

    visit team_conversations_url(@team)

    click_on first.title
    assert_selector ".Conversation--active .Conversation__contact", text: first.title
    click_on last.title
    assert_selector ".Conversation--active .Conversation__contact", text: last.title
  end

  test "showing the contact info pane" do
    visit team_conversation_url(@team, @conversation)
    assert_selector ".ContactDetail:not([src])", visible: :all
    click_on "Profil et notes"
    assert_selector ".ContactDetail[src]"
    assert_selector ".ContactDetail .Contact__name", text: @conversation.title
  end

  teardown do
    @conversation.contact.destroy
  end
end
