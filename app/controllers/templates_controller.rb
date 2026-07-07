class TemplatesController < ApplicationController
  layout "viewer"

  before_action :set_team
  before_action :set_user
  before_action :authorize_templates_owner!, only: %i[ index new create ]
  before_action :set_templates
  before_action :set_template, only: %i[ edit update destroy ]

  # GET /teams/:team_slug/users/:id/templates
  def index
  end

  # GET /teams/:team_slug/users/:id/templates/new
  def new
    @template = Template.new(user: @user)
  end

  # POST team/:team_slug/users/:id/templates
  def create
    @template = @user.templates.build(template_params.except(:shared))
    @template.team = @team if template_params[:shared] == "1"
    authorize! :manage, @template

    if @template.save
      respond_to do |format|
        format.html { redirect_to team_user_templates_path(@team, @user) }
        format.turbo_stream {
          flash.now[:notice] = I18n.t("templates.create.success")
        }
      end
    else
      redirect_to team_user_templates_path(@team, @user), notice: I18n.t("templates.create.not_blank")
    end
  end

  # GET /teams/:team_slug/users/:id/templates/edit
  def edit
  end

  # PATCH/PUT team/:team_slug/users/:id/templates/:id
  def update
    respond_to do |format|
      if @template.update(template_params.except(:shared))
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

  # Listing, creating a new personal template, or getting a form only make
  # sense for the user in the route (or a super admin) -- own it or beat it.
  def authorize_templates_owner!
    authorize! :manage, Template.new(user: @user)
  end

  def set_templates
    @personal_templates = @user.templates.personal
    @team_templates = @team.templates
  end

  # Editing/updating/destroying a template can target either a personal
  # template of the user in the route, or any template shared with the
  # team -- team templates are editable by every team member. Authorize
  # the found instance rather than just the route-level owner gate, so
  # that any team member (not just @user) can act on a shared template.
  def set_template
    scope = @user.templates.personal.or(Template.shared.where(team: @team))
    @template = scope.find(params[:id])
    authorize! :manage, @template
  end

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_team
    @team = Current.team || Team.find_by!(slug: params[:team_id])
  end

  # Only allow a list of trusted parameters through.
  def template_params
    params.fetch(:template, {}).permit(:title, :content, :shared)
  end
end
