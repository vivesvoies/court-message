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
    @conversation = @message.conversation

    if @message.save
      outbound = OutboundMessagesService.new(@message)
      @conversation.messages << @message

      if outbound.submit!
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to [ @conversation.team, @conversation ] }
        end
      else
        handle_response_with_errors
      end
    else
      handle_response_with_errors
    end
  end

  private

  def message_params
    params.fetch(:message).permit(:conversation_id, :content)
  end

  def handle_response_with_errors
    respond_to do |format|
      format.html {
        flash.now[:notice] = @message.errors.full_messages.join(", ")
        render :new, status: :unprocessable_entity
      }
      format.turbo_stream {
        flash.now[:notice] = @message.errors.full_messages.join(", ")
      }
    end
  end
end
