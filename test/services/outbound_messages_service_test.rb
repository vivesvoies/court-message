require "test_helper"

class OutboundMessagesServiceTest < ActiveSupport::TestCase
  def setup
    Current.user = create(:user)

    c = create(:conversation)
    @message = Message.new({ content: "Lorem Ipsum", conversation_id: c.id, sender: Current.user })
    @contact = c.contact
    # With no PhoneLine configured, sends fall back to the legacy number.
    @from = PhoneLine.legacy_number
    @provider = Minitest::Mock.new
    @outbound_message = OutboundMessagesService.new(@message, @provider)
  end

  def test_creates_message_instance
    assert(@outbound_message.message.unsent_status?)
    assert(@outbound_message.message.valid?)
  end

  def test_submits_message_to_service
    @provider.expect(
      :send,
      ProviderResult.new(success: true, message_uuid: SecureRandom.uuid),
      from: @from, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert(@outbound_message.submit!)
    assert(@outbound_message.message.submitted_status?)
    assert(@outbound_message.message.outbound_uuid.present?)
    assert(@outbound_message.message.valid?)

    @provider.verify
  end

  def test_submits_message_to_service_unavailable
    @provider.expect(
      :send,
      ProviderResult.new(success: false, error: "HTTP Status: 503, Response Body: Service Unavailable."),
      from: @from, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert_not(@outbound_message.submit!)
    assert(@outbound_message.message.failed_status?)
    assert(@outbound_message.message.save!)

    @provider.verify
  end

  def test_submits_message_to_service_failure_without_error_details
    @provider.expect(
      :send,
      ProviderResult.new(success: false),
      from: @from, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert_not(@outbound_message.submit!)
    assert(@outbound_message.message.failed_status?)
    assert(@outbound_message.message.save!)

    @provider.verify
  end

  def test_queued_result_keeps_message_unsent
    @provider.expect(
      :send,
      ProviderResult.new(success: true, queued: true, message_uuid: SecureRandom.uuid),
      from: @from, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert(@outbound_message.submit!)
    assert(@outbound_message.message.unsent_status?)
    assert(@outbound_message.message.outbound_uuid.present?)

    @provider.verify
  end

  def test_routes_through_the_team_phone_line
    line = create(:phone_line)
    conversation = create(:conversation)
    conversation.contact.team.update!(phone_line: line)

    service = OutboundMessagesService.new(Message.new(content: "Hi", conversation:, sender: Current.user), @provider)

    assert_equal(line, service.message.phone_line)
  end

  def test_routes_through_the_fallback_line_when_the_team_line_is_inactive
    fallback = create(:phone_line)
    line = create(:phone_line, active: false, fallback_phone_line: fallback)
    conversation = create(:conversation)
    conversation.contact.team.update!(phone_line: line)

    service = OutboundMessagesService.new(Message.new(content: "Hi", conversation:, sender: Current.user), @provider)

    assert_equal(fallback, service.message.phone_line)
  end

  def test_routes_through_the_default_line_without_a_team_line
    default = create(:phone_line, default: true)

    service = OutboundMessagesService.new(Message.new(content: "Hi", conversation: create(:conversation), sender: Current.user), @provider)

    assert_equal(default, service.message.phone_line)
  end

  def test_selects_sms_gateway_provider_for_gateway_lines
    line = create(:gateway_phone_line)
    message = Message.new(content: "Lorem Ipsum", conversation: @message.conversation, sender: Current.user, phone_line: line)

    service = OutboundMessagesService.new(message)

    assert(service.submit!)
    # Queued for the gateway: stays unsent until the gateway claims it and
    # reports the outcome, but already has an outbound UUID.
    assert(message.unsent_status?)
    assert(message.outbound_uuid.present?)
    assert(message.persisted?)
  end
end
