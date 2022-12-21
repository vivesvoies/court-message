require "test_helper"

class InboundMessagesServiceTest
  class KnownContact < ActiveSupport::TestCase
    def test_creates_message
      contact = create(:contact)
      params = { to: "our phone number", from: contact.phone, text: "Hello" }

      message = InboundMessagesService.new(params).message

      message.save
      assert(message.persisted?)
      assert_equal(message.conversation, contact.conversation)
    end
  end

  class UnknownContact < ActiveSupport::TestCase
    def test_creates_message_contact_convo
      params = { to: "our phone number", from: fake_number, text: "Coucou" }

      message = InboundMessagesService.new(params).message
      contact = message.sender

      message.save
      assert(message.persisted?)
      assert(contact.persisted?)
      assert_equal(message.sender_type, "Contact")
      assert_equal(message.conversation, contact.conversation)
    end
  end
end
