class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[ destroy ]
  before_action :set_team, only: %i[ new ]
  authorize_resource :team
  authorize_resource

  def new
    @users = User.where.not(id: @team.memberships.pluck(:user_id))
    @membership = Membership.new(team: @team)
  end

  def create
    @membership = Membership.new(membership_params)
    @team = @membership.team

    authorize! :create, @membership
    if @membership.save
      redirect_to edit_team_path(@team) # , notice: "Membre ajouté à l’équipe."
    else
      redirect_to edit_team_path(@team), alert: @membership.errors.full_messages.join(", ")
    end
  end

  def destroy
    @team = @membership.team
    authorize! :destroy, @membership
    @membership.destroy
    redirect_to team_path(@team), status: :see_other # , notice: t("users.destroy.destroyed")
  end

  private

  def set_team
    @team = Team.find(params[:team_id])
  end

  def set_membership
    @membership = Membership.find(params[:id])
  end

  def membership_params
    params.fetch(:membership, {}).permit(:user_id, :team_id)
  end
end
