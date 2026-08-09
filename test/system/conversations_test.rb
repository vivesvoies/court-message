require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @team = create(:team)
    @user = create(:user, teams: [ @team ])

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

  test "creating a contact from a search that matches nothing" do
    contact = build(:contact)

    visit team_conversations_url(@team)
    click_on "Écrire un message"

    fill_in "query", with: contact.name
    assert_selector ".ContactSearchResult__no-contact"

    click_on "Nouveau contact"
    fill_in "contact_name", with: contact.name
    fill_in "contact_phone", with: contact.phone
    fill_in "contact_email", with: contact.email
    click_on "Enregistrer le contact"

    assert_no_selector "#error_explanation"

    visit team_conversations_url(@team)
    assert_selector ".Conversation__contact", text: contact.name
  end

  test "being responsive" do
    resize_to_mobile

    visit team_conversations_url(@team)
    # The navigation frame is lazy-loaded: measuring before it resolves reads 0.
    assert_selector "#navigation .Conversation__contact", minimum: 1

    viewer_width = width_of("viewer")
    assert_in_delta viewer_width, width_of("navigation"), 1

    click_on @conversation.contact.to_s, match: :first
    assert_selector "#conversation_detail .Message__content", minimum: 1

    assert_in_delta 0, width_of("navigation"), 1
    assert_in_delta viewer_width, width_of("conversation_detail"), 1

    resize_to_desktop
    assert_selector "#navigation .Conversation__contact", minimum: 1

    assert width_of("navigation") > 0
    assert width_of("conversation_detail") > 0
  end

  test "selecting current conversation" do
    @contacts = create_list(:contact, 3, :with_conversation, team: @team)

    first = @contacts.first.conversation
    last = @contacts.last.conversation

    visit team_conversations_url(@team)

    click_on first.title
    assert_selector ".Conversation--active .Conversation__contact", text: first.title
    click_on last.title
    assert_selector ".Conversation--active .Conversation__contact", text: last.title
  end

  test "toggling between conversation and contact" do
    visit team_conversation_url(@team, @conversation)
    assert_selector "#messages .Message__content", text: @message.content

    # Both tab bars render tab_for :contacts, so the id appears twice; scope to
    # the one inside the conversation pane.
    within ".ViewerDetail__TabBar" do
      click_on "Répertoire"
    end
    assert_selector ".ContactDetail"
    assert_text @conversation.contact.name

    within ".ViewerDetail__TabBar" do
      click_on "Messagerie"
    end
    assert_selector "#messages .Message__content", text: @message.content
  end

  private

  def width_of(id)
    page.evaluate_script("document.getElementById('#{id}').getBoundingClientRect().width")
  end
end
