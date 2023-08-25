class TeamsController < ApplicationController
  before_action :set_team, only: %i[ show edit update destroy ]
  authorize_resource

  # GET /teams
  def index
    @teams = Current.user.teams
    redirect_to team_conversations_path(@teams.first) unless show_picker?
  end

  # GET /teams/1
  def show
    redirect_to team_conversations_path(@team)
  end

  # GET /teams/new
  def new
    @team = Team.new
  end

  # GET /teams/1/edit
  def edit
  end

  # POST /teams
  def create
    @team = Team.new(team_params)

    if @team.save
      redirect_to @team, notice: "Team was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /teams/1
  def update
    if @team.update(team_params)
      redirect_to @team, notice: "Team was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /teams/1
  def destroy
    @team.destroy
    redirect_to teams_url, notice: "Team was successfully destroyed.", status: :see_other
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
