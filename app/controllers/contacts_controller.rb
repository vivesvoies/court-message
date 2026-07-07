class ContactsController < ApplicationController
  layout :set_layout

  before_action :set_team
  before_action :set_contact, only: %i[ show edit update destroy ]
  authorize_resource :team
  authorize_resource

  # GET team/:team_slug/contacts
  def index
    @contacts = @team.contacts.order(name: :asc)
    @last = @contacts.where(created_by_id: current_user.id).order(created_at: :desc).first
  end

  # GET team/:team_slug/contacts/:id
  def show
  end

  # GET team/:team_slug/contacts/search?query=:query
  def search
    @query = params[:query]
    @results = @query.blank? ? [] : Contact.search_team(@team, @query)
  end

  # GET team/:team_slug/contacts/new
  def new
    @create_conversation = ActiveModel::Type::Boolean.new.cast(params[:create_conversation])
    @contact = Contact.new(team_id: @team.id)
    if current_frame == "modal"
      render "conversations/new" and return
    end
  end

  # GET team/:team_slug/contacts/:id/edit
  def edit
  end

  # POST team/:team_slug/contacts
  def create
    @contact = Contact.new(contact_params)
    @contact.team = @team
    @contact.created_by = Current.user
    authorize! :create, @contact
    # INFO: Parts of the app will break if the conversation is not created.
    # See _viewer_detail_tab_bar.html.erb for instance.
    if params[:create_conversation]
      @contact.build_conversation
    end

    if @contact.save
      redirect_to team_contact_path(@team, @contact), notice: I18n.t(".contacts.create.success")
    else
      render "errors/error", status: 422
    end
  end

  # PATCH/PUT team/:team_slug/contacts/:id
  def update
    if @contact.update(contact_params)
      redirect_to edit_team_contact_path(@team, @contact), notice: I18n.t("contacts.update.success")
    else
      render "errors/error", status: 422
    end
  end

  # DELETE team/:team_slug/contacts/:id
  def destroy
    @contact.destroy
    redirect_to team_contacts_path(@team), notice: I18n.t(".contacts.destroy.success")
  end

  private

  def set_layout
    current_frame == "modal" ? "modal" : "viewer"
  end

  # Use callbacks to share common setup or constraints between actions.
  # Contacts are only reachable through their own team's routes.
  def set_contact
    @contact = @team.contacts.find(params[:id])
  end

  def set_team
    @team = Current.team || Team.find_by!(slug: params[:team_id])
  end

  # Only allow a list of trusted parameters through.
  def contact_params
    params.fetch(:contact, {}).permit(:name, :email, :phone, :notes)
  end
end
