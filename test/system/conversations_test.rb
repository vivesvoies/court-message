require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @conversation = create(:conversation)
    @message = create(:inbound_message, conversation: @conversation)
    @conversation.messages << @message
  end

  test "visiting the index" do
    visit conversations_url
    assert_selector ".Conversation__contact", text: @conversation.contact.name_or_phone
  end

  test "opening a conversation" do
    visit conversations_url
    click_on @conversation.contact.name_or_phone, match: :first
    assert_selector ".Message", text: @message.content
  end

  test "being responsive" do
    resize_to_mobile

    visit conversations_url
    click_on @conversation.contact.name_or_phone, match: :first
    assert_selector ".Conversation__contact", text: @conversation.contact.name_or_phone, visible: :hidden
    assert_selector ".Message__content", text: @message.content, visible: true

    resize_to_desktop
    assert_selector ".Conversation__contact", visible: true
    assert_selector ".Message__content", text: @message.content, visible: true
  end
end
