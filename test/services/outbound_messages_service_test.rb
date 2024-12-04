require "test_helper"

class OutboundMessagesServiceTest < ActiveSupport::TestCase
  def setup
    Current.user = create(:user)
    Current.phone_number = fake_number

    c = create(:conversation)
    message = Message.new({ content: "Lorem Ipsum", conversation_id: c.id, sender: Current.user })
    @contact = c.contact
    @provider = Minitest::Mock.new
    @outbound_message = OutboundMessagesService.new(message, @provider)
  end

  def test_creates_message_instance
    assert(@outbound_message.message.unsent_status?)
    assert(@outbound_message.message.valid?)
  end

  def test_submits_message_to_service
    @provider.expect(
      :send,
      OpenStruct.new(message_uuid: :message_uuid, http_response: Net::HTTPSuccess.new(1.0, "200", "OK")),
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert(@outbound_message.submit!)
    assert(@outbound_message.message.submitted_status?)
    assert(@outbound_message.message.valid?)

    @provider.verify
  end

  def test_submits_message_to_service_unavailable
    @provider.expect(
      :send,
      OpenStruct.new(message_uuid: :message_uuid, http_response: Net::HTTPServiceUnavailable.new(1.1, "503", "Service Unavailable")),
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert_not(@outbound_message.submit!)
    assert(@outbound_message.message.failed_status?)
    assert(@outbound_message.message.save!)

    @provider.verify
  end

  def test_submits_message_to_service_bad_request
    @provider.expect(
      :send,
      OpenStruct.new(message_uuid: :message_uuid, http_response: Net::HTTPBadRequest.new(1.1, "400", "Bad Request")),
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert_not(@outbound_message.submit!)
    assert(@outbound_message.message.failed_status?)
    assert(@outbound_message.message.save!)

    @provider.verify
  end

  def test_submits_message_to_service_unauthorized
    @provider.expect(
      :send,
      OpenStruct.new(message_uuid: :message_uuid, http_response: Net::HTTPUnauthorized.new(1.1, "401", "Unauthorized")),
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert_not(@outbound_message.submit!)
    assert(@outbound_message.message.failed_status?)
    assert(@outbound_message.message.save!)

    @provider.verify
  end

  def test_submits_message_to_service_server_error
    @provider.expect(
      :send,
      OpenStruct.new(message_uuid: :message_uuid, http_response: Net::HTTPInternalServerError.new(1.1, "500", "Internal Server Error")),
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert_not(@outbound_message.submit!)
    assert(@outbound_message.message.failed_status?)
    assert(@outbound_message.message.save!)

    @provider.verify
  end
end
