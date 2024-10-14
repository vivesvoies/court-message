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
    expected_uuid = SecureRandom.uuid
    @provider.expect(
      :send,
      OpenStruct.new(message_uuid: expected_uuid, http_response: Net::HTTPSuccess.new(1.0, "200", "OK")),
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert(@outbound_message.submit!)
    assert(@outbound_message.message.submitted_status?)
    assert(@outbound_message.message.valid?)

    @provider.verify
  end
end
