class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[ show edit update destroy ]

  # GET /conversations
  def index
    # TODO: eager loading EVERY MESSAGE, this is overkill. Should create a last_message_id column.
    # See https://github.com/louije/court-message/issues/47
    @conversations = Conversation.all.includes(:contact, :messages).order(updated_at: :desc)
  end

  # GET /conversations/1
  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_conversation
    @conversation = Conversation.includes({ messages: :sender }, :contact, :agents).find(params[:id])
  end

  # # Only allow a list of trusted parameters through.
  # def conversation_params
  #   params.fetch(:conversation, {})
  # end
end
