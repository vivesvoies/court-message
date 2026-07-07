class MessagesController < ApplicationController
  RETRYABLE_STATUSES = %i[ failed expired rejected undeliverable ].freeze

  authorize_resource only: [ :new, :create ]

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
      MessageDeliveryJob.perform_later(@message)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to [ @conversation.team, @conversation ] }
      end
    else
      handle_response_with_errors
    end
  end

  def retry
    @message = Message.find(params[:id])
    authorize! :create, @message

    unless @message.direction == :outbound && RETRYABLE_STATUSES.include?(@message.status.to_sym)
      return head :unprocessable_entity
    end

    @message.update!(status: :unsent)
    MessageDeliveryJob.perform_later(@message)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: [ @message.conversation.team, @message.conversation ] }
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
