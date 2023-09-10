class ReadStatusController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_conversation
  before_action :set_status
  authorize_resource :conversation

  def update
    if @status == "read"
      @conversation.mark_as_read!
      head :ok
    elsif @status == "unread"
      @conversation.mark_as_unread!
      head :ok
    else 
      render status: :unprocessable_entity
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def set_status
    @status = params.require(:read_status).permit(:status)[:status]
  end
end
