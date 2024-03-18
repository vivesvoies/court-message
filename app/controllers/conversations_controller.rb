class ConversationsController < ApplicationController
  before_action :set_team, only: %i[ index show ]
  before_action :load_conversations, only: %i[ index show ]
  before_action :set_conversation, only: %i[ show ]

  authorize_resource :team
  authorize_resource

  # GET /conversations
  def index
    set_conversation if params[:id]
  end

  # GET /conversations/1
  def show
    @conversation.mark_as_read! if @conversation.unread?
    unless params[:detail]
      render :index
    end
  end

  private

  # WIP
  def load_conversations
    which_convos = params[:show]
    # https://cm.fr/team/conversations/4?show=all
    # https://cm.fr/team/conversations?show=all
    if which_convos == "mine"
      # @conversations = Conversation.for_team(@team).where(user: Current.user)
      @conversations = Conversation.for_team(@team).where(user: Current.user)
    else
      @conversations = Conversation.for_team(@team)
    end
  end

  def set_conversation
    @conversation = Conversation.find_preloaded(params[:id])
  end

  def set_team
    @team = Current.team || Team.find_by(slug: params[:team_id])
  end

  # # Only allow a list of trusted parameters through.
  # def conversation_params
  #   params.fetch(:conversation, {})
  # end
end
