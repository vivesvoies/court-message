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
      redirect_to team_path(@team), notice: I18n.t("memberships.create.added")
    else
      redirect_to team_path(@team), alert: @membership.errors.full_messages.join(", ")
    end
  end

  def destroy
    @team = @membership.team
    authorize! :destroy, @membership

    user = @membership.user

    # Remove team membership
    @membership.destroy
    user.reload

    # Delete the user if he never had an active account
    if user.can_be_deleted?
      user.destroy
    end

    # Delete the invitation if the user has been invited
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to user.awaiting_invitation_reply? ? remove_user_team_invitation_path(@team, user.invitation_token) : team_path(@team), status: :see_other, notice: I18n.t("memberships.destroy.destroyed") }
    end
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
