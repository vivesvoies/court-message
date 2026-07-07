require "test_helper"

class OutboundMessagesServiceTest < ActiveSupport::TestCase
  def setup
    Current.user = create(:user)
    Current.phone_number = fake_number
    Current.phone_line = nil

    c = create(:conversation)
    @message = Message.new({ content: "Lorem Ipsum", conversation_id: c.id, sender: Current.user })
    @contact = c.contact
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
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
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
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
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
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
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
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert(@outbound_message.submit!)
    assert(@outbound_message.message.unsent_status?)
    assert(@outbound_message.message.outbound_uuid.present?)

    @provider.verify
  end

  def test_assigns_current_phone_line_to_message
    line = create(:phone_line)
    Current.phone_line = line

    service = OutboundMessagesService.new(Message.new(content: "Hi", conversation: @message.conversation, sender: Current.user), @provider)

    assert_equal(line, service.message.phone_line)
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
