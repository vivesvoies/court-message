class MessagesController < ApplicationController
  def new
    @message = Message.new
    @message.conversation = Conversation.find(params[:conversation_id])
  end

  def create
    @message = Message.new(message_params)
    @message.sender = Current.user
    outbound = OutboundMessagesService.new(@message)

    @message.save
    if !@message.persisted?
      # TODO: renders only the `new` frame
      render :new, status: :unprocessable_entity and return
    end

    if outbound.submit!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @message.conversation }
      end
    else
      # TODO: probably a different kind of error
      render :new, status: :unprocessable_entity
    end
  end

  private

  def message_params
    params.fetch(:message).permit(:conversation_id, :content)
  end
end
