require "test_helper"

class OutboundMessagesServiceTest < ActiveSupport::TestCase
  def setup
    Current.phone_number = fake_number
    Current.user = create(:user)

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
      Struct.new(:message_uuid).new("abc-abc"),
      from: Current.phone_number, to: @contact.phone, content: "Lorem Ipsum"
    )

    assert(@outbound_message.submit!)
    assert(@outbound_message.message.submitted_status?)
    assert(@outbound_message.message.valid?)

    @provider.verify
  end
end
