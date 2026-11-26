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

  test "the status changes the conversation" do
    patch read_status_team_conversation_url(@team, @conversation, read_status: { status: "unread" })
    assert @conversation.reload.unread?

    patch read_status_team_conversation_url(@team, @conversation, read_status: { status: "read" })
    assert @conversation.reload.read?
  end

  # The conversation is found by id alone: the team in the URL is not trusted.
  test "an agent outside the conversation's team cannot change its status" do
    outsider = create(:user)
    sign_in outsider

    patch read_status_team_conversation_url(outsider.teams.first, @conversation, read_status: { status: "unread" })
    assert_response :forbidden

    patch read_status_team_conversation_url(@team, @conversation, read_status: { status: "unread" })
    assert_response :forbidden

    assert @conversation.reload.read?
  end
end
