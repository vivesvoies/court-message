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

    @invited_by__name = User.find(resource.invited_by_id)
    @team = Team.find(User.find(resource.id).team_ids.first).name
    @is_admin = resource.role != "user"
    render :welcome
  end

  def new
    # FIXME: The set_team before_action and authorize_ressource does not work for an unknown reason
    @team = Team.find_by(slug: params[:team])
    unless Current.user.belongs_to_team?(@team)
      raise CanCan::AccessDenied, "You are not authorized to invite users to this team."
    end
    super
  end

  def create
    # FIXME: The set_team before_action and authorize_ressource does not work for an unknown reason
    @team = Team.find_by(slug: params[:team])
    user = User.find_by(email: invite_params[:email])
    part_of_team = user && user.belongs_to_team?(@team)

    # This is to prevent a user from being invited to a team to which the current user does not belong
    unless Current.user.belongs_to_team?(@team)
      raise CanCan::AccessDenied, "You are not authorized to invite users to this team."
    end

    # If the user is confirmed no invitation is sent
    if user && !user.awaiting_invitation_reply?
      if part_of_team
        redirect_to team_path(@team), notice: I18n.t("devise.invitations.user_already_in_the_team")
        return
      end
      # If the user is not a team member the membership is created
      Membership.create(team: @team, user: user)
      redirect_to team_path(@team), notice: I18n.t(".invitations.notice.user_add_to_team")
      return
    end
    super
    Membership.create(team: @team, user: User.find(resource.id)) unless part_of_team
  end

  def after_invite_path_for(resource)
    # FIXME: The set_team before_action and authorize_ressource does not work for an unknown reason
    team_url(Team.find_by(slug: params[:team]))
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite, keys: [ :name, :phone ])
    devise_parameter_sanitizer.permit(:accept_invitation, keys: [ :name, :email, :phone ])
  end
end
