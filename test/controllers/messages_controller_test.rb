require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @contact = create(:contact, :with_conversation, team: @team)
    @conversation = @contact.conversation

    @message = create(:outbound_message, conversation: @conversation)

    @from = PhoneLine.legacy_number

    @expected_uuid = SecureRandom.uuid

    @provider_success = Minitest::Mock.new
    @provider_success.expect(
      :send,
      ProviderResult.new(success: true, message_uuid: @expected_uuid),
      from: @from, to: @conversation.contact.phone, content: @message.content
    )

    sign_in(@user)
  end

  test "should not get index" do
    assert_raises(ActionController::RoutingError) {
      get messages_url
    }
  end

  test "should get new" do
    get new_message_url(conversation_id: @conversation.id)
    assert_response :success
  end

  test "should not get new without a conversation_id" do
    assert_raises(ActiveRecord::RecordNotFound) {
      get new_message_url
    }
  end

  test "should not get new without a conversation_id the user has access to" do
    other_conversation = create(:conversation)
    get new_message_url(conversation_id: other_conversation.id)

    assert_response :forbidden
  end

  test "should create message" do
    OutboundMessagesService.stub(:new, OutboundMessagesService.new(@message, @provider_success)) do
      assert_difference("Message.count", 1) do
        post messages_url, params: { message: { conversation_id: @conversation.id, content: @message.content } }
      end

      assert_redirected_to team_conversation_url(@team, @conversation)
    end

    @provider_success.verify
  end

  test "should not create message in conversations the user does not have access to" do
    other_conversation = create(:conversation)

    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: other_conversation.id, content: "Hello" } }
    end
    assert_response :forbidden
  end

  test "should not create message with blank content" do
    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "" } }
    end

    assert_response :unprocessable_entity
    assert_match /Le contenu du message ne peut être vide/, flash[:notice]
  end

  test "should not create message with only spaces" do
    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "   " } }
    end

    assert_response :unprocessable_entity
    assert_match /Le contenu du message ne peut être vide/, flash[:notice]
  end

  test "should not create message with only tabs" do
    assert_no_difference("Message.count") do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "\t\t\t" } }
    end

    assert_response :unprocessable_entity
    assert_match /Le contenu du message ne peut être vide/, flash[:notice]
  end

  test "should not show message" do
    assert_raises(NoMethodError) {
      get message_url(@message)
    }
  end

  test "should not get edit" do
    assert_raises(NoMethodError) {
      get edit_message_url(@message)
    }
  end

  test "should not update message" do
    # See OutboundMessagesControllerTest for message status update tests
    assert_raises(NoMethodError) {
      patch message_url(@message), params: { message: {} }
    }
  end

  test "should not destroy message" do
    assert_raises(NoMethodError) {
      delete message_url(@message)
    }
  end

  test "should set Conversation#last_message on create" do
    OutboundMessagesService.stub(:new, OutboundMessagesService.new(@message, @provider_success)) do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "Heya" } }
      assert_equal("Heya", @conversation.reload.last_message.content)
      assert_equal(Message.last, @conversation.last_message)

      assert_redirected_to team_conversation_url(@team, @conversation)
    end

    @provider_success.verify
  end

  test "should associate message with conversation and update last_message" do
    OutboundMessagesService.stub(:new, OutboundMessagesService.new(@message, @provider_success)) do
      post messages_url, params: { message: { conversation_id: @conversation.id, content: "Test message" } }

      assert_equal("Test message", @conversation.reload.last_message.content)
      assert_equal(Message.last, @conversation.last_message)
    end

    @provider_success.verify
  end

  test "should create message if provider fails" do
    @provider_fail = Minitest::Mock.new

    @provider_fail.expect(
      :send,
      ProviderResult.new(success: false, error: "HTTP Status: 503, Response Body: Service Unavailable."),
      from: @from, to: @conversation.contact.phone, content: @message.content
    )

    OutboundMessagesService.stub(:new, OutboundMessagesService.new(@message, @provider_fail)) do
      assert_difference("Message.count", 1) do
        post messages_url, params: { message: { conversation_id: @conversation.id, content: @message.content } }
      end

      assert_response :unprocessable_entity
    end

    @provider_fail.verify
  end

  test "should handle failed outbound message submission" do
    post outbound_messages_path, params: { message_uuid: @message.outbound_uuid, status: "failed" }

    assert_equal "failed", @message.reload.status
    assert_response :ok
  end
end

class MessageRetryTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @team = @user.teams.first
    @line = create(:gateway_phone_line, :online, modem_ok: true, last_modem_check_at: Time.current)
    @team.update!(phone_line: @line)
    @conversation = create(:contact, :with_conversation, team: @team).conversation
    @old_uuid = SecureRandom.uuid
    @failed = create(:outbound_message, conversation: @conversation, status: :undeliverable,
                     phone_line: @line, outbound_uuid: @old_uuid, claimed_at: 1.hour.ago,
                     provider_info: { "delivery_report" => { "code" => 65 } })
    sign_in(@user)
  end

  test "sends an undelivered message again, keeping the failed attempt" do
    post retry_message_url(@failed), as: :turbo_stream

    assert_response :success
    @failed.reload
    assert_equal "unsent", @failed.status, "queued for the gateway again"
    assert_not_nil @failed.outbound_uuid
    assert_not_equal @old_uuid, @failed.outbound_uuid
    assert_nil @failed.claimed_at
    attempt = @failed.provider_info["attempts"].sole
    assert_equal({ "status" => "undeliverable", "outbound_uuid" => @old_uuid, "phone" => @line.phone, "delivery_report" => { "code" => 65 } },
                 attempt.except("at"))
    assert_nil @failed.provider_info["delivery_report"]
  end

  test "routes the retry through the team's current line" do
    vonage = create(:phone_line, provider: "vonage", default: true)
    @failed.update!(phone_line: vonage, status: :rejected, claimed_at: nil)

    post retry_message_url(@failed), as: :turbo_stream

    assert_equal @line, @failed.reload.phone_line
  end

  test "a failover marker does not survive the retry, so it can fail over again" do
    @failed.update!(provider_info: { "fallback" => { "from" => "a", "to" => "b" } })

    post retry_message_url(@failed), as: :turbo_stream

    assert_nil @failed.reload.provider_info["fallback"]
  end

  test "keeps every failed attempt, one per retry" do
    post retry_message_url(@failed), as: :turbo_stream
    @failed.reload.update!(status: :undeliverable)

    post retry_message_url(@failed), as: :turbo_stream

    assert_equal 2, @failed.reload.provider_info["attempts"].size
  end

  # A second click must not send twice. Clicks at the very same moment are
  # covered by the row lock in MessagesController#retry, which a test inside
  # one shared transaction cannot race.
  test "a second click on the same retry sends nothing more" do
    provider = Minitest::Mock.new
    provider.expect(:send, ProviderResult.new(success: true, message_uuid: SecureRandom.uuid), from: String, to: String, content: String)
    @team.update!(phone_line: create(:phone_line, provider: "vonage"))

    DummyProvider.stub(:new, provider) do
      post retry_message_url(@failed), as: :turbo_stream
      post retry_message_url(@failed), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    provider.verify
    assert_equal 1, @failed.reload.provider_info["attempts"].size
  end

  test "does not resend a message that was delivered or is under way" do
    %i[delivered submitted unsent].each do |status|
      @failed.update!(status:)
      post retry_message_url(@failed), as: :turbo_stream
      assert_response :unprocessable_entity
      assert_equal status.to_s, @failed.reload.status
    end
  end

  test "does not resend an inbound message" do
    inbound = create(:inbound_message, conversation: @conversation)
    post retry_message_url(inbound), as: :turbo_stream
    assert_response :unprocessable_entity
  end

  test "agents outside the team cannot resend" do
    sign_in create(:user)
    post retry_message_url(@failed), as: :turbo_stream
    assert_response :forbidden
    assert_equal "undeliverable", @failed.reload.status
  end
end
