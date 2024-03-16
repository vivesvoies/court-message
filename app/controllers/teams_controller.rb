class TeamsController < ApplicationController
  before_action :set_team, only: %i[ show edit menu update destroy ]
  authorize_resource

  # GET /teams
  def index
    @teams = Current.user.teams
    redirect_to team_conversations_path(@teams.first) unless show_picker?
  end

  # GET /teams/:team_slug
  def show
  end

  # GET /teams/:team_slug/menu
  def menu
    if request.headers["Turbo-Frame"] != "conversation_sidebar"
      redirect_to team_conversations_path(@team)
    end
  end

  # GET /teams/new
  def new
    @team = Team.new
  end

  # GET /teams/:team_slug/edit
  def edit
  end

  # POST /teams
  def create
    @team = Team.new(team_params)

    if @team.save
      Membership.create(team: @team, user: Current.user)
      redirect_to @team, notice: I18n.t("teams.create.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /teams/:team_slug
  def update
    if @team.update(team_params)
      redirect_to @team, notice: I18n.t("teams.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /teams/:team_slug
  def destroy
    @team.destroy
    redirect_to teams_path, notice: I18n.t("teams.destroy.destroyed"), status: :see_other
  end

  private

  def show_picker?
    params[:picker] == "show" || @teams.count != 1 || can?(:create, Team)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_team
    @team = Team.find_by(slug: params[:id])
  end

  # Only allow a list of trusted parameters through.
  def team_params
    params.fetch(:team, {}).permit(:name, :address)
  end
end
