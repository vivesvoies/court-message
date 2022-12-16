require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @conversation = conversations(:one)
  end

  test "visiting the index" do
    visit conversations_url
    assert_selector "h1", text: "Conversations"
  end

  test "should create conversation" do
    visit conversations_url
    click_on "New conversation"

    click_on "Create Conversation"

    assert_text "Conversation was successfully created"
    click_on "Back"
  end

  test "should update Conversation" do
    visit conversation_url(@conversation)
    click_on "Edit this conversation", match: :first

    click_on "Update Conversation"

    assert_text "Conversation was successfully updated"
    click_on "Back"
  end

  test "should destroy Conversation" do
    visit conversation_url(@conversation)
    click_on "Destroy this conversation", match: :first

    assert_text "Conversation was successfully destroyed"
  end
end
