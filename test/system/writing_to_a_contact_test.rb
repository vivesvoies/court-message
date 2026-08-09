require "application_system_test_case"

# The main path into the app: press "Écrire un message", search for someone,
# pick them from the results and land in their conversation.
class WritingToAContactTest < ApplicationSystemTestCase
  setup do
    @team = create(:team)
    @user = create(:user, teams: [ @team ])
    @contact = create(:contact, team: @team, name: "Ambroise Deschamps")
    @conversation = create(:conversation, contact: @contact)
    @message = create(:inbound_message, conversation: @conversation, content: "Bonjour")

    sign_in @user
  end

  test "writing to a contact on desktop" do
    resize_to_desktop

    visit team_conversations_url(@team)
    click_on "Écrire un message"

    fill_in "query", with: "Ambroise"
    assert_selector ".ContactSearchResult__name", text: @contact.name

    click_on @contact.name

    assert_selector "#messages .Message__content", text: @message.content
  end

  test "writing to a contact on mobile" do
    skip "the search loads into a collapsed pane on mobile, see #448"
    resize_to_mobile

    visit team_conversations_url(@team)
    click_on "Écrire un message"

    fill_in "query", with: "Ambroise"
    assert_selector ".ContactSearchResult__name", text: @contact.name

    click_on @contact.name

    assert_selector "#messages .Message__content", text: @message.content
  end

  test "moving between the bottom tabs on mobile" do
    resize_to_mobile
    visit team_conversations_url(@team)

    within ".TabBar" do
      click_on "Répertoire"
    end
    assert_selector ".ContactIndex, .ContactPage"

    within ".TabBar" do
      click_on "Modèles"
    end
    assert_selector ".Templates, .TemplateList, [data-controller~=templates]"

    within ".TabBar" do
      click_on "Messagerie"
    end
    assert_selector ".Conversation__contact", text: @contact.name
  end
end
