class MessagesController < ApplicationController
  authorize_resource

  def new
    @message = Message.new
    @message.conversation = Conversation.find(params[:conversation_id])
    authorize! :new, @message
  end

  def create
    # Should preload conversation in order to get contact's phone number.
    @message = Message.new(message_params)
    authorize! :create, @message

    @message.sender = Current.user
    outbound = OutboundMessagesService.new(@message)

    @conversation = @message.conversation
    @message.save
    @conversation.messages << @message

    if !@message.persisted?
      # TODO: renders only the `new` frame
      # Instead show an error message.
      # See https://github.com/louije/court-message/issues/15
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream {
          flash[:error] = @message.errors.full_messages.join(", ")
        }
      end
      return
    end

    if outbound.submit!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to [ @conversation.team, @conversation ] }
      end
    else
      # TODO: probably a different kind of error
      # See https://github.com/louije/court-message/issues/13
      render :new, status: :unprocessable_entity
    end
  end

  private

  def message_params
    params.fetch(:message).permit(:conversation_id, :content)
  end
end
