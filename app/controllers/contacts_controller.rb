class ContactsController < ApplicationController
  before_action :set_team, only: %i[ index show new edit update destroy ]
  before_action :set_contact, only: %i[ show edit update destroy ]
  authorize_resource :team
  authorize_resource

  # GET team/:team_slug/contacts
  def index
    @contacts = Contact.all
  end

  # GET team/:team_slug/contacts/:id
  def show
  end

  # GET team/:team_slug/contacts/new
  def new
    @create_conversation = ActiveModel::Type::Boolean.new.cast(params[:create_conversation])
    @contact = Contact.new(team_id: @team.id)
    if params[:modal]
      render "conversations/new" and return
    end
  end

  # GET team/:team_slug/contacts/:id/edit
  def edit
  end

  # POST team/:team_slug/contacts
  def create
    @contact = Contact.new(new_contact_params)
    if params[:create_conversation]
      @contact.build_conversation
    end
    @team = @contact.team

    if @contact.save
      respond_to do |format|
        format.html { redirect_to team_contact_path(@team, @contact) }
        format.turbo_stream {
          flash.now[:notice] = I18n.t(".contacts.create.success")
        }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT team/:team_slug/contacts/:id
  def update
    if @contact.update(contact_params)
      redirect_to edit_team_contact_path(@team, @contact), notice: I18n.t(".contacts.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE team/:team_slug/contacts/:id
  def destroy
    @team = @contact.team
    @conversation = @contact.conversation

    @contact.destroy
    respond_to do |format|
      format.html { redirect_to team_contacts_path(@team), notice: I18n.t(".contacts.destroy.success") }
      format.turbo_stream {
        flash.now[:notice] = I18n.t(".contacts.destroy.success")
      }
    end
  end

  private

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
