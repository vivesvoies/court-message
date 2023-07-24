class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[ destroy ]
  before_action :set_team, only: %i[ new ]

  def new
    @users = User.where.not(id: @team.memberships.pluck(:user_id))
    @membership = Membership.new(team: @team)
  end

  def create
    @membership = Membership.new(membership_params)
    @team = @membership.team
    if @membership.save
      redirect_to @team # , notice: "Membre ajouté à l’équipe."
    else
      redirect_to @team, alert: @membership.errors.full_messages.join(", ")
    end
  end

  def destroy
    @team = @membership.team
    @membership.destroy
    redirect_to @team, status: :see_other # , notice: t("memberships.destroy.destroyed")
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
