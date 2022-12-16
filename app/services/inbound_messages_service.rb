# This class is responsible for parsing inbound requests
# and creating Message objects.
# If necessary, Contact and Conversation records will also be created.
class InboundMessagesService
  attr_reader :message

  def initialize(params)
    sender = Contact.find_or_initialize_by(phone: params[:from])
    conversation = sender.conversation || sender.build_conversation
    content = params[:text]

    @message = Message.new(sender:, conversation:, content:)
  end
end
