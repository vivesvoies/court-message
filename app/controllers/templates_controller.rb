class TemplatesController < ApplicationController
  layout "viewer"

  before_action :set_templates, only: %i[ new create edit update destroy ]
  before_action :set_template, only: %i[ edit update destroy ]
  before_action :set_team, only: %i[ index new create edit update ]
  before_action :set_user, only: %i[ new create edit update ]
  load_and_authorize_resource

  # GET /teams/:team_slug/users/:id/templates
  def index
  end

  # GET /teams/:team_slug/users/:id/templates/new
  def new
    @template = Template.new(user_id: @user.id)
  end

  # POST team/:team_slug/users/:id/templates
  def create
    @template = Template.new(new_template_params)
    @user.templates << @template

    if @template.save
      respond_to do |format|
        format.html { redirect_to team_user_templates_path(@team, @user) }
        format.turbo_stream {
          flash.now[:notice] = I18n.t("templates.create.success")
        }
      end
    elsif !@template.valid?
      redirect_to team_user_templates_path(@team, @user), notice: I18n.t("templates.create.not_blank")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /teams/:team_slug/users/:id/templates/edit
  def edit
  end

  # PATCH/PUT team/:team_slug/users/:id/templates/:id
  def update
    respond_to do |format|
      if @template.update(template_params)
        format.html { redirect_to team_user_templates_path, notice: I18n.t("templates.update.template_updated") }
        format.turbo_stream
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@template) }
      end
    end
  end

  # DELETE team/:team_slug/users/:id/templates/:id
  def destroy
    @template.destroy
    respond_to do |format|
      format.html { redirect_to team_user_templates_path, notice: I18n.t("templates.destroy.success") }
      format.turbo_stream {
        flash.now[:notice] = I18n.t("templates.destroy.success")
      }
    end
  end

  private

  def set_templates
    @templates = User.find(params[:user_id]).templates
  end

  def set_template
    @template = Template.find(params[:id])
  end

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_team
    @team = Current.team || Team.find_by(slug: params[:team_id])
  end

  # Only allow a list of trusted parameters through.
  def template_params
    params.fetch(:template, {}).permit(:content)
  end

  def new_template_params
    params.fetch(:template, {}).permit(:content, :user_id)
  end
end
