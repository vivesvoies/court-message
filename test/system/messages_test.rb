require "application_system_test_case"

class MessagesTest < ApplicationSystemTestCase
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @conversation = create(:conversation, contact: create(:contact, team: @team))
    10.times do
      create(:inbound_message, conversation: @conversation, sender: @conversation.contact)
      create(:outbound_message, conversation: @conversation, sender: @user)
    end

    sign_in @user

    resize_to_desktop
  end

  test "streaming a new message" do
    message = create(:inbound_message, conversation: @conversation)

    visit team_conversation_url(@team, @conversation)
    # Waiting for the message to render also waits for the stream subscription:
    # broadcasting before it is live loses the update with nothing to retry.
    assert_selector ".Message__content", text: message.content

    message.update!(content: "New content!")

    assert_selector ".Message__content", text: "New content!"
  end

  test "anchoring the message list" do
    visit team_conversation_url(@team, @conversation)
    assert_selector "#messages .Message__content", minimum: 1

    scroll_before = message_list_scroll_top
    create(:inbound_message, conversation: @conversation, content: "Anchor me")
    assert_selector ".Message__content", text: "Anchor me"

    assert scroll_before < message_list_scroll_top
  end

  private

  def message_list_scroll_top
    page.evaluate_script('document.getElementById("messages").scrollTop')
  end
end
