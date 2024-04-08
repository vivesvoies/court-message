class ContactsController < ApplicationController
  layout :set_layout

  before_action :set_team, only: %i[ index show new edit update destroy search ]
  before_action :set_contact, only: %i[ show edit update destroy ]
  authorize_resource :team
  authorize_resource

  # GET team/:team_slug/contacts
  def index
    @contacts = @team.contacts
  end

  # GET team/:team_slug/contacts/:id
  def show
  end

  def search
    @contacts = Contact.all
    @search = params[:query]
    @results = if @search.blank?
                 []
               else
                 Contact.where('name ILIKE :search', search: "%#{@search}%")
               end
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
    @contact = Contact.new(new_contact_params)
    # INFO: Parts of the app will break if the conversation is not created.
    # See _viewer_detail_tab_bar.html.erb for instance.
    if params[:create_conversation]
      @contact.build_conversation
    end
    @team = @contact.team

    if @contact.save
      redirect_to team_contact_path(@team, @contact), notice: I18n.t(".contacts.create.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT team/:team_slug/contacts/:id
  def update
    if @contact.update(contact_params)
      redirect_to edit_team_contact_path(@team, @contact), notice: I18n.t("contacts.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE team/:team_slug/contacts/:id
  def destroy
    @team = @contact.team
    @contact.destroy
    redirect_to team_contacts_path(@team), notice: I18n.t(".contacts.destroy.success")
  end

  private

  def set_layout
    current_frame == "modal" ? "modal" : "viewer"
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_contact
    @contact = Contact.find(params[:id])
  end

  def set_team
    @team = Current.team || Team.find_by(slug: params[:team_id])
  end

  # Only allow a list of trusted parameters through.
  def contact_params
    params.fetch(:contact, {}).permit(:name, :email, :phone, :notes)
  end

  def new_contact_params
    params.fetch(:contact, {}).permit(:name, :email, :phone, :notes, :team_id)
  end
end
