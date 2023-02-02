class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[ show edit update destroy ]

  # GET /conversations
  def index
    @conversations = Conversation.all.order(updated_at: :desc)
  end

  # GET /conversations/1
  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_conversation
    @conversation = Conversation.includes(:messages, :contact, :agents).find(params[:id])
  end

  # # Only allow a list of trusted parameters through.
  # def conversation_params
  #   params.fetch(:conversation, {})
  # end
end
