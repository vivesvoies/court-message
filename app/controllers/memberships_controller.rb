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
      redirect_to team_path(@team) # , notice: "Membre ajouté à l’équipe."
    else
      redirect_to team_path(@team), alert: @membership.errors.full_messages.join(", ")
    end
  end

  def destroy
    @team = @membership.team
    authorize! :destroy, @membership

    user = User.find(@membership.user_id)

    # Remove team membership
    @membership.destroy

    # Delete user if does not belong to a team
    if user.team_ids.empty?
      user.destroy
    # Delete the invitation if the user has been invited
    elsif user.awaiting_invitation_reply?
      redirect_to remove_user_team_invitation_path(@team, user.invitation_token)
      return
    end

    redirect_to team_path(@team), status: :see_other # , notice: t("memberships.destroy.destroyed")
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
