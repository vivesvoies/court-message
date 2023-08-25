require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contact = create(:contact)
    @temp = build(:contact)
    @user = create(:user, teams: [@contact.team])

    sign_in(@user)
  end

  test "should not get index" do
    assert_raises(ActionController::RoutingError) {
      get contacts_url
    }
  end

  test "should not get new without a team_id param" do
    assert_raises(ActiveRecord::RecordNotFound) {
      get new_contact_url
    }
  end

  test "should get new with a team_id param" do
    get new_contact_url(team_id: @user.teams.first.id)
    assert_response :success
  end

  test "should not get new with a wrong team_id param" do
    other_team = create(:team)
    get new_contact_url(team_id: other_team.id)
    assert_response :forbidden
  end

  test "should create contact and no conversation" do
    assert_difference -> { Contact.count } => 1, -> { Conversation.count } => 0 do
      post contacts_url,
           params: { contact: { name: @temp.name, email: @temp.email, phone: @temp.phone,
                                team_id: @user.teams.first.id } }
    end

    assert_redirected_to contact_url(Contact.last)
  end

  test "should create conversation when flag is set" do
    assert_difference(["Contact.count", "Conversation.count"]) do
      post contacts_url,
           params: {
             contact: { name: @temp.name, email: @temp.email, phone: @temp.phone,
                        team_id: @user.teams.first.id }, create_conversation: true
           }
    end

    assert_redirected_to contact_url(Contact.last)
  end

  test "should show contact" do
    get contact_url(@contact)
    assert_response :success
  end

  test "should not show contact from another team" do
    other_contact = create(:contact)
    get contact_url(other_contact)
    assert_response :forbidden
  end

  test "should get edit" do
    get edit_contact_url(@contact)
    assert_response :success
  end

  test "should update contact" do
    patch contact_url(@contact), params: { contact: { name: "Other name" } }
    assert_redirected_to contact_url(@contact)
  end

  test "should not update contact team" do
    @initial_team = @contact.team
    @new_team = create(:team)

    patch contact_url(@contact), params: { contact: { name: "Other name", team_id: @new_team.id } }
    assert_redirected_to contact_url(@contact)
    @contact.reload

    assert_equal(@initial_team, @contact.team)
  end

  test "should destroy contact" do
    team = @contact.team

    assert_difference("Contact.count", -1) do
      delete contact_url(@contact)
    end

    assert_redirected_to team_conversations_url(team)
  end
end
