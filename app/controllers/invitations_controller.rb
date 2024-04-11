class InvitationsController < Devise::InvitationsController
  before_action :configure_permitted_parameters

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
