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
    assert_nil(contact)

    message.save
    assert_not(message.persisted?)
  end

  def test_save_persists_and_marks_the_conversation_unread
    contact = create(:contact, :with_conversation)
    contact.conversation.update!(read: true)
    service = InboundMessagesService.new({ to: "our phone number", from: contact.phone, text: "Hello" })

    assert(service.save)
    assert(service.message.persisted?)
    assert_not(contact.conversation.reload.read)
  end

  def test_save_returns_false_for_an_unknown_sender
    service = InboundMessagesService.new({ to: "our phone number", from: fake_number, text: "Hello" })

    assert_not(service.save)
    assert_not(service.message.persisted?)
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
