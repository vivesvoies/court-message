class InvitationsController < Devise::InvitationsController
  before_action :configure_permitted_parameters

  def welcome
    @invitation_token = params[:invitation_token]
    self.resource = resource_class.find_by_invitation_token(@invitation_token, true)

    # If the token isn't valid or the resource doesn't exist
    unless resource
      redirect_to user_session_path(), notice: I18n.t(".devise.invitations.invitation_token_invalid")
      return
    end

    # Check if the user is already authenticated
    if user_signed_in?
      redirect_to teams_path, notice: I18n.t(".devise.failure.already_authenticated")
      return
    end

    @invited_by = User.find(resource.invited_by_id)
    team_id = resource.team_ids.first
    @team = Team.find(team_id).name
    @is_admin = resource.memberships.find_by(team_id: team_id)&.admin_role? || false
  end

  def new
    @team = Team.find_by(slug: params[:team])
    unless Current.user.belongs_to_team?(@team)
      redirect_to @team, notice: I18n.t(".invitations.notice.not_authorized")
      return
    end
    super
  end

  def create
    @team = Team.find_by(slug: params[:team])
    user = User.find_by(email: invite_params[:email])
    part_of_team = user && user.belongs_to_team?(@team)

    # This is to prevent a user from being invited to a team to which the current user does not belong
    unless Current.user.belongs_to_team?(@team)
      redirect_to @team, notice: I18n.t(".invitations.notice.not_authorized")
      return
    end

    # If the user is confirmed no invitation is sent
    if user && !user.awaiting_invitation_reply?
      if part_of_team
        redirect_to team_path(@team), notice: I18n.t("devise.invitations.user_already_in_the_team")
        return
      end
      # If the user is not a team member the membership is created
      Membership.create(team: @team, user: user, role: invited_membership_role)
      redirect_to team_path(@team), notice: I18n.t(".invitations.notice.user_add_to_team")
      return
    end
    super
    Membership.create(team: @team, user: User.find(resource.id), role: invited_membership_role) unless part_of_team
  end

  def after_invite_path_for(resource)
    team_url(Team.find_by(slug: params[:team]))
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite, keys: [ :name, :phone ])
    devise_parameter_sanitizer.permit(:accept_invitation, keys: [ :name, :email, :phone ])
  end

  # Membership role granted to the invitee. Only a team admin of @team (or a
  # site/super admin) may grant the `admin` role; everyone else invites members.
  def invited_membership_role
    return "member" unless params[:role] == "admin"
    return "member" unless Current.user.team_admin_of?(@team) || Current.user.at_least?(:site_admin)
    "admin"
  end
end
