require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @conversation = create(:conversation)
    @message = create(:inbound_message, conversation: @conversation)
    @conversation.messages << @message

    @user = create(:user)
    sign_in @user
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

  test "being responsive" do
    resize_to_mobile

    visit conversations_url
    body_width = page.evaluate_script('document.body.getBoundingClientRect().width')
    list_width = page.evaluate_script('document.getElementById("conversations").getBoundingClientRect().width')
    assert_equal(list_width, body_width)

    click_on @conversation.contact.name_or_phone, match: :first
    list_width = page.evaluate_script('document.getElementById("conversations").getBoundingClientRect().width')
    conv_width = page.evaluate_script('document.getElementById("conversation_detail").getBoundingClientRect().width')
    assert_equal(list_width, 0)
    assert_equal(conv_width, body_width)

    resize_to_desktop
    body_width = page.evaluate_script('document.body.getBoundingClientRect().width')
    list_width = page.evaluate_script('document.getElementById("conversations").getBoundingClientRect().width')
    conv_width = page.evaluate_script('document.getElementById("conversation_detail").getBoundingClientRect().width')
    assert(list_width > 0)
    assert(conv_width > 0)
    assert_equal(conv_width + list_width, body_width)
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
