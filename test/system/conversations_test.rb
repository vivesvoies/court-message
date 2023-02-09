require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @conversation = create(:conversation)
    @message = create(:inbound_message, conversation: @conversation)
    @conversation.messages << @message

    @user = create(:user)
    sign_in @user

    resize_to_desktop
  end

  test "visiting the index" do
    visit conversations_url
    assert_selector ".Conversation__contact", text: @conversation.contact.to_s
  end

  test "opening a conversation" do
    visit conversations_url
    click_on @conversation.contact.to_s, match: :first
    assert_selector ".Message__content", text: @message.content
  end

  test "loading conversation path shows sidebar" do
    visit conversations_url
    click_on @conversation.contact.to_s, match: :first
    sleep 0.5
    assert_equal conversation_url(@conversation), current_url

    visit current_url
    assert_selector ".Message__content", text: @message.content
    assert_selector ".Conversation__contact", text: @conversation.contact.to_s
  end

  test "creating a new conversation" do
    contact = build(:contact)

    visit conversations_url
    click_on "Nouvelle conversation"
    fill_in "contact_name", with: contact.name
    fill_in "contact_phone", with: contact.phone
    fill_in "contact_email", with: contact.email
    click_on "Créer la fiche"

    visit conversations_url

    assert_selector ".Conversation__contact", text: contact.name
  end

  test "being responsive" do
    resize_to_mobile

    visit conversations_url
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

    visit conversations_url

    click_on first.title
    assert_selector ".Conversation--active .Conversation__contact", text: first.title
    click_on last.title
    assert_selector ".Conversation--active .Conversation__contact", text: last.title
  end

  test "streaming a new message" do
    visit conversation_url(@conversation)
    sleep 0.5
    @message.update(content: "New content!")
    @message.broadcast_update
    sleep 0.5
    find ".Message__content"
    assert_selector ".Message__content", text: "New content!"
  end

  teardown do
    @conversation.contact.destroy
  end
end
