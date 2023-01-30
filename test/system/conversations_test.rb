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
    assert_selector ".Conversation__contact", text: @conversation.contact.name_or_phone
  end

  test "opening a conversation" do
    visit conversations_url
    click_on @conversation.contact.name_or_phone, match: :first
    assert_selector ".Message__content", text: @message.content
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
    list_width = page.evaluate_script('document.getElementById("conversation_master").getBoundingClientRect().width')
    assert_equal(list_width, viewer_width)

    click_on @conversation.contact.name_or_phone, match: :first
    list_width = page.evaluate_script('document.getElementById("conversation_master").getBoundingClientRect().width')
    conv_width = page.evaluate_script('document.getElementById("conversation_detail").getBoundingClientRect().width')
    assert_equal(list_width, 0)
    assert_equal(conv_width, viewer_width)

    resize_to_desktop
    viewer_width = page.evaluate_script('document.getElementById("viewer").getBoundingClientRect().width')
    list_width = page.evaluate_script('document.getElementById("conversation_master").getBoundingClientRect().width')
    conv_width = page.evaluate_script('document.getElementById("conversation_detail").getBoundingClientRect().width')
    assert(list_width > 0)
    assert(conv_width > 0)
    assert_equal(conv_width + list_width, viewer_width)
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
