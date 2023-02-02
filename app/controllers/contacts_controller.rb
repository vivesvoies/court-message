class ContactsController < ApplicationController
  before_action :set_contact, only: %i[ show edit update destroy ]

  # GET /contacts
  def index
    @contacts = Contact.all
  end

  # GET /contacts/1
  def show
  end

  # GET /contacts/new
  def new
    @create_conversation = ActiveModel::Type::Boolean.new.cast(params[:create_conversation])
    @contact = Contact.new
    if params[:modal]
      render "conversations/new" and return
    end
  end

  # GET /contacts/1/edit
  def edit
  end

  # POST /contacts
  def create
    @contact = Contact.new(contact_params)
    if params[:create_conversation]
      @contact.build_conversation
    end

    if @contact.save
      respond_to do |format|
        format.html { redirect_to @contact, notice: "Contact was successfully created." }
        format.turbo_stream {
          flash.now[:notice] = "Contact was successfully created."
          render turbo_stream: turbo_stream.prepend("conversations", partial: "conversations/conversation",
                                                                     locals: { conversation: @contact.conversation })
        }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /contacts/1
  def update
    if @contact.update(contact_params)
      redirect_to @contact, notice: I18n.t(".contacts.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /contacts/1
  def destroy
    @contact.destroy
    redirect_to root_url, notice: "Contact was successfully destroyed."
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_contact
    @contact = Contact.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def contact_params
    params.fetch(:contact, {}).permit(:name, :email, :phone)
  end
end
