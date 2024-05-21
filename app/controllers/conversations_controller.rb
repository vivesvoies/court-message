class ConversationsController < ApplicationController
  layout "viewer"

  before_action :set_team, only: %i[ index show create update ]
  before_action :all_conversations, only: %i[ index ]
  before_action :set_conversation, only: %i[ show ]
  before_action :set_templates, only: %i[ index show ]

  authorize_resource :team
  authorize_resource

  # GET team/:team_slug/conversations
  def index
    if params[:show] == "mine"
      @conversations = Conversation.for_user(current_user, @team)
    else
      @conversations = Conversation.for_team(@team)
    end
  end

  # POST team/:team_slug/conversations
  def create
    contact = Contact.find(params[:contact])
    contact.build_conversation
    contact.save
    redirect_to team_conversation_path(@team, contact.conversation), notice: I18n.t(".conversations.create.success")
  end

  # GET team/:team_slug/conversations/1
  def show
    all_conversations if current_frame.nil? # Don't need to load conversation list on turbo-frame requests
    @conversation.mark_as_read! if @conversation.unread?
  end

  private

  def all_conversations
    @conversations = Conversation.for_team(@team)
  end

  def set_conversation
    @conversation = Conversation.find_preloaded(params[:id])
  end

  def set_team
    @team = Current.team || Team.find_by(slug: params[:team_id])
  end

  def set_templates
    @templates = Current.user.templates if !turbo_frame_request?
  end

  # # Only allow a list of trusted parameters through.
  # def conversation_params
  #   params.fetch(:conversation, {})
  # end
end
