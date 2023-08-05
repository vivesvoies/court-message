# This class is responsible for parsing inbound requests
# and creating Message objects.
# If no contact is found, will not create it.

# TODO: Currently only supports SMS through Vonage.
# TODO: When the same phone number belongs to a Contact in different teams.
# TODO: Notify of inbound messages that don't have a corresponding Contact

class InboundMessagesService
  attr_reader :message

  def initialize(params)
    phone = PhonyRails.normalize_number(params[:from])
    sender = Contact.find_by(phone:) # TODO: handle contacts that belong to multiple Teams

    conversation = sender&.conversation || sender&.build_conversation
    content = params[:text]

    @message = Message.new(sender:, conversation:, content:, provider_info: params, status: :inbound)
  end
end
