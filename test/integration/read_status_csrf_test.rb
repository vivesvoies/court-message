require "test_helper"

# Read status is changed by a fetch() from the conversation list, inside the
# user's session: it must carry the page's CSRF token, like any form. A
# missing or forged token raises InvalidAuthenticityToken (the test
# environment does not rescue exceptions; production answers 422).
class ReadStatusCsrfTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @conversation = create(:contact, :with_conversation, team: @team).conversation
    @conversation.update!(read: false)
    sign_in(@user)

    @allow_forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @allow_forgery_protection
  end

  test "rejects a read status change without the CSRF token" do
    assert_raises(ActionController::InvalidAuthenticityToken) { mark_as_read(token: nil) }

    assert_not(@conversation.reload.read)
  end

  test "rejects a read status change with a forged CSRF token" do
    assert_raises(ActionController::InvalidAuthenticityToken) { mark_as_read(token: "forged") }

    assert_not(@conversation.reload.read)
  end

  test "accepts the page's CSRF token, sent the way the conversation list sends it" do
    get team_conversations_url(@team)
    token = css_select('meta[name="csrf-token"]').first["content"]

    mark_as_read(token:)

    assert_response :ok
    assert(@conversation.reload.read)
  end

  private

  # Same request as markAsRead() in conversation_list_controller.js.
  def mark_as_read(token:)
    headers = { "Content-Type" => "application/json" }
    headers["X-CSRF-Token"] = token if token
    patch read_status_team_conversation_url(@team, @conversation), params: { status: "read" }.to_json, headers:
  end
end
