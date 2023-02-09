require "application_system_test_case"

class MessagesTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @conversation = create(:conversation)
    10.times do
      create(:inbound_message, conversation: @conversation, sender: @conversation.contact)
      create(:outbound_message, conversation: @conversation, sender: @user)
    end

    sign_in @user

    resize_to_desktop
  end

  test "streaming a new message" do
    @message = create(:inbound_message, conversation: @conversation)

    visit conversation_url(@conversation)
    sleep 0.5
    @message.update(content: "New content!")
    sleep 0.5
    assert_selector ".Message__content", text: "New content!"
  end

  test "anchoring the message list" do
    visit conversation_url(@conversation)

    current_scroll = page.evaluate_script('document.getElementById("messages").scrollTop')
    @message = create(:inbound_message, conversation: @conversation)
    sleep 0.5
    new_scroll = page.evaluate_script('document.getElementById("messages").scrollTop')
    assert(new_scroll > current_scroll)
  end
end
