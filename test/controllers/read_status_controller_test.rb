require "test_helper"

class ReadStatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @contact = create(:contact, :with_conversation, team: @team)
    @conversation = @contact.conversation
    sign_in @user
  end

  test "should set mark as read" do
    patch read_status_team_conversation_url(@team, @conversation, read_status: { status: "read" })

    assert_response :success
  end

  test "should set mark as unread" do
    patch read_status_team_conversation_url(@team, @conversation, read_status: { status: "unread" })

    assert_response :success
  end

  test "should fail otherwise" do
    patch read_status_team_conversation_url(@team, @conversation, read_status: { status: "other" })
    assert_response :bad_request

    assert_raises(ActionController::ParameterMissing) do
      patch read_status_team_conversation_url(@team, @conversation)
    end
  end
end
