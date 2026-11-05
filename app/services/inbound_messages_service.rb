# This class is responsible for parsing inbound requests
# and creating Message objects, whichever channel they arrive on (Vonage
# webhook or one of our SMS gateways).
# If no contact is found, will not create it.

# TODO: When the same phone number belongs to a Contact in different teams.
# TODO: Notify of inbound messages that don't have a corresponding Contact

class InboundMessagesService
  attr_reader :message

  def initialize(params, phone_line: nil)
    phone = PhonyRails.normalize_number(params[:from])
    sender = Contact.find_by(phone:) # TODO: handle contacts that belong to multiple Teams

    conversation = sender&.find_or_create_conversation!
    content = params[:text]

    @message = Message.new(sender:, conversation:, content:, provider_info: params, status: :inbound, phone_line:)
  end

  # Persists the message and flags its conversation as unread. Returns false
  # when the message is invalid, e.g. the sender matches no Contact.
  def save
    return false unless @message.valid?

    ActiveRecord::Base.transaction do
      @message.save!
      @message.conversation.mark_as_unread!
    end

    @message.persisted?
  end
end
