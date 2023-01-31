# This class is responsible for parsing inbound requests
# and creating Message objects.
# If necessary, Contact and Conversation records will also be created.
# Currently only supports SMS through Vonage.
class InboundMessagesService
  attr_reader :message

  def initialize(params)
    phone = PhonyRails.normalize_number(params[:from])
    sender = Contact.find_or_initialize_by(phone:)
    conversation = sender.conversation || sender.build_conversation
    content = params[:text]

    @message = Message.new(sender:, conversation:, content:, provider_info: params, status: :inbound)
  end
end
