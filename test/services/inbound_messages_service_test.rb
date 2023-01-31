require "test_helper"

class InboundMessagesServiceTest < ActiveSupport::TestCase
  def test_creates_message
    contact = create(:contact)
    params = { to: "our phone number", from: contact.phone, text: "Hello" }

    message = InboundMessagesService.new(params).message

    message.save
    assert(message.persisted?)
    assert(message.inbound_status?)
    assert_equal(message.conversation, contact.conversation)
  end

  def test_creates_message_contact_and_convo
    params = { to: "our phone number", from: fake_number, text: "Coucou" }

    message = InboundMessagesService.new(params).message
    contact = message.sender

    message.save
    assert(message.persisted?)
    assert(contact.persisted?)
    assert_equal(message.sender_type, "Contact")
    assert_equal(message.conversation, contact.conversation)
  end

  def test_finds_the_correct_contact
    contact = create(:contact)
    phone = contact.phone.phony_formatted(national: true)
    params = { to: "our phone number", from: phone, text: "Hello" }

    message = InboundMessagesService.new(params).message

    message.save
    assert(message.persisted?)
    assert(message.inbound_status?)
    assert_equal(message.conversation, contact.conversation)
  end
end
