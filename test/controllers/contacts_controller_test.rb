require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contact = create(:contact, :with_conversation)
    @temp = build(:contact)
    @team = @contact.team
    @user = create(:user, teams: [ @contact.team ])

    sign_in(@user)
  end

  test "should get index" do
    get team_contacts_url(@team)
    assert_response :success
  end

  test "should get index with last contact created" do
    new_contact = create(:contact, team: @team, created_by: @user)
    get team_contacts_url(@team)

    assert_response :success
    assert_select ".ContactIndex__last-contact-link", text: "#{new_contact.name}"
  end

  test "should get index without error even with a nameless contact" do
    Contact.create(email: "contact-mail@com", phone: "0102030405")
    get team_contacts_url(@team)
    assert_response :success
  end

  test "should only see contacts belonging to user's team on index page" do
    get team_contacts_url(@user.teams.first)

    assert_response :success
    assert_select ".Contact" do |name_elements|
      displayed_contact_names = name_elements.map { |element| element.at_css(".Contact__name").text.strip }

      user_team_contact_names = @user.teams.first.contacts.pluck(:name)

      displayed_contact_names.each do |contact_name|
        assert_includes user_team_contact_names, contact_name
      end
    end
  end

  test "should get new" do
    get new_team_contact_url(@team)
    assert_response :success
  end

  test "should create new contact with correct team_id even with wrong team_id param" do
    other_team = create(:team)
    get new_team_contact_url(@team), params: { team_id: other_team.id }
    assert_response :success
    assert_equal(Contact.last.team_id, @team.id)
  end

  test "should create contact" do
    assert_difference("Contact.count") do
      post team_contacts_url(@team), params: { contact: { name: "John Doe", email: "john@example.com", phone: "0123456789", team_id: @team.id } }
    end

    assert_redirected_to team_contact_url(@team, Contact.last)
  end

  test "should not create contact with invalid attributes" do
    assert_no_difference("Contact.count") do
      post team_contacts_url(@team), params: { contact: { name: nil, email: "john@example.com", phone: "1234567890", team_id: @team.id } }
    end

    assert_response :unprocessable_entity
  end

  test "should not create contact with phone already existing" do
    assert_difference("Contact.count") do
      post team_contacts_url(@team), params: { contact: { name: "John Doe", email: "john@example.com", phone: "0123456789", team_id: @team.id } }
    end
    assert_no_difference("Contact.count") do
      post team_contacts_url(@team), params: { contact: { name: nil, email: "johnDoe@example.com", phone: "1234567890", team_id: @team.id } }
    end

    assert_response :unprocessable_entity
  end

  test "should create contact and no conversation" do
    assert_difference -> { Contact.count } => 1, -> { Conversation.count } => 0 do
      post team_contacts_url(@team),
           params: { contact: { name: @temp.name, email: @temp.email, phone: @temp.phone,
                                team_id: @user.teams.first.id } }
    end

    assert_redirected_to team_contact_url(@team, Contact.last)
  end

  test "should create conversation when flag is set" do
    assert_difference([ "Contact.count", "Conversation.count" ]) do
      post team_contacts_url(@team),
           params: {
             contact: { name: @temp.name, email: @temp.email, phone: @temp.phone,
                        team_id: @user.teams.first.id }, create_conversation: true
           }
    end

    assert_redirected_to team_contact_url(@team, Contact.last)
  end

  test "should show contact" do
    get team_contact_url(@team, @contact)
    assert_response :success
  end

  test "should not show contact from another team" do
    other_contact = create(:contact)
    get team_contact_url(@team, other_contact)
    assert_response :forbidden
  end

  test "should get edit" do
    get edit_team_contact_url(@team, @contact)
    assert_response :success
  end

  test "should update contact" do
    patch team_contact_url(@team, @contact), params: { contact: { name: "Other name" } }
    assert_redirected_to edit_team_contact_url(@team, @contact)
  end

  test "should update notes_updated_at and notes_last_editor_id contact" do
    assert_nil(@contact.notes_updated_at)
    assert_nil(@contact.notes_last_editor_id)
    assert_changes -> { @contact.notes_updated_at } do
      patch team_contact_url(@team, @contact), params: { contact: { notes: "Some new notes" } }
      assert_redirected_to edit_team_contact_url(@team, @contact)
      @contact.reload
    end
    assert_equal(@contact.notes_last_editor_id, @user.id)
  end

  test "should not update contact team" do
    @initial_team = @contact.team
    @new_team = create(:team)

    patch team_contact_url(@team, @contact), params: { contact: { name: "Other name", team_id: @new_team.id } }
    assert_redirected_to edit_team_contact_url(@team, @contact)
    @contact.reload

    assert_equal(@initial_team, @contact.team)
  end

  test "should destroy contact" do
    team = @contact.team
    @message = create(:outbound_message, conversation: @contact.conversation)

    assert_difference("Contact.count", -1) do
      delete team_contact_url(@team, @contact)
    end

    assert_redirected_to team_contacts_url(team)
  end

  test "should destroy contact and associated records" do
    @message = create(:inbound_message, content: "0123456789" * 15)
    @contact.conversation.messages << @message

    assert_not_nil Contact.find_by(id: @contact.id)
    assert_not_nil Conversation.find_by(id: @contact.conversation.id)
    assert_not_nil Message.find_by(id: @message.id)
    assert_not_nil @contact.conversation.last_message_id

    assert_difference("Contact.count", -1) do
      assert_difference("Conversation.count", -1) do
        assert_difference("Message.count", -1) do
          delete team_contact_url(@team, @contact)
          assert_response :redirect
          follow_redirect!
          assert_response :success
          assert_match I18n.t(".contacts.destroy.success"), response.body
        end
      end
    end
  end

  test "should search contacts by name" do
    get search_team_contacts_url(@team), params: { query: @contact.name }
    assert_response :success
    assert_select "li.ContactSearchResult__name" do
      assert_select "a", text: @contact.name
    end
    assert_select "li.ContactSearchResult__name", count: 1
  end

  test "should search contacts by email" do
    get search_team_contacts_url(@team), params: { query: @contact.email }
    assert_response :success
    assert_select "li.ContactSearchResult__name" do
      assert_select "a", text: @contact.name
    end
    assert_select "li.ContactSearchResult__name", count: 1
  end

  test "should search contacts by phone" do
    get search_team_contacts_url(@team), params: { query: @contact.phone }
    assert_response :success
    assert_select "li.ContactSearchResult__name" do
      assert_select "a", text: @contact.name
    end
    assert_select "li.ContactSearchResult__name", count: 1
  end

  test "should not return contacts if search query is empty" do
    get search_team_contacts_url(@team), params: { query: "" }
    assert_response :success
    assert_select "li.ContactSearchResult__name", count: 0
    assert_select "li.ContactSearchResult__no-contact", count: 0
  end

  test "should return no contacts if search query does not match any name" do
    get search_team_contacts_url(@team), params: { query: "NonExistentName" }
    assert_response :success
    assert_select "li.ContactSearchResult__name", count: 0
    assert_select "li.ContactSearchResult__no-contact", count: 1
  end

  test "should return no contacts if contact is not in the team" do
    contact = create(:contact, :with_conversation)
    build(:contact)
    get search_team_contacts_url(@team), params: { query: contact.name }
    assert_response :success
    assert_select "li.ContactSearchResult__name", count: 0
    assert_select "li.ContactSearchResult__no-contact", count: 1
  end
end
