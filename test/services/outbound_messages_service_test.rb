require "test_helper"

class OutboundMessagesServiceTest < ActiveSupport::TestCase
  def setup
    Current.user = create(:user)
    @from_number = Rails.configuration.x.outbound_phone_number

    c = create(:conversation)
    @message = Message.create!({ content: "Lorem Ipsum", conversation_id: c.id, sender: Current.user })
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
      OpenStruct.new(message_uuid: :message_uuid, http_response: Net::HTTPSuccess.new(1.0, "200", "OK")),
      from: @from_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert(@outbound_message.submit!)
    assert(@outbound_message.message.submitted_status?)
    assert(@outbound_message.message.valid?)

    @provider.verify
  end

  def test_raises_and_keeps_status_when_service_unavailable
    assert_delivery_error_for(Net::HTTPServiceUnavailable.new(1.1, "503", "Service Unavailable"))
  end

  def test_raises_and_keeps_status_on_bad_request
    assert_delivery_error_for(Net::HTTPBadRequest.new(1.1, "400", "Bad Request"))
  end

  def test_raises_and_keeps_status_on_unauthorized
    assert_delivery_error_for(Net::HTTPUnauthorized.new(1.1, "401", "Unauthorized"))
  end

  def test_raises_and_keeps_status_on_server_error
    assert_delivery_error_for(Net::HTTPInternalServerError.new(1.1, "500", "Internal Server Error"))
  end

  private

  # A refusal must raise (so the delivery job can retry with backoff) and
  # leave the message unsent instead of marking it failed right away.
  def assert_delivery_error_for(http_response)
    @provider.expect(
      :send,
      OpenStruct.new(message_uuid: :message_uuid, http_response:),
      from: @from_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert_raises(OutboundMessagesService::DeliveryError) { @outbound_message.submit! }
    assert(@outbound_message.message.reload.unsent_status?)

    @provider.verify
  end
end
