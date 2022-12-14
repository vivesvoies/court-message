require "test_helper"

class InboundMessagesServiceTest
  class KnownContact < ActiveSupport::TestCase
    def test_creates_message
      contact = create(:contact)
      params = { to: "our phone number", from: contact.phone, text: "Hello" }

      message = InboundMessagesService.new(params).message
      assert(message.valid?)
      assert(message.conversation == contact.conversation)
    end
  end

  class UnknownContact < ActiveSupport::TestCase
    def test_creates_message_contact_convo
      params = { to: "our phone number", from: Faker::PhoneNumber.cell_phone_in_e164, text: "Coucou" }

      message = InboundMessagesService.new(params).message
      contact = message.sender

      assert(message.valid?)
      assert(message.sender_type == "Contact")
      assert(contact.valid?)
      assert(message.conversation == contact.conversation)
    end
  end
end
