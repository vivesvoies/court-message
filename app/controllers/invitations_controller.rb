class InvitationsController < Devise::InvitationsController
  before_action :configure_permitted_parameters

  def create
    team = Team.find_by(slug: params[:team_id])
    user = User.find_by_email(invite_params[:email].strip)
    # If the user is not a team member the membership is automatically created
    Membership.create(team: team, user: User.find(invite_resource.id)) unless user && user.belongs_to_team?(team)
    # If the user is confirmed no invitation is sent
    if user && !user.awaiting_invitation_reply?
      if user.belongs_to_team?(team)
        redirect_to team_url(team), notice: I18n.t("devise.invitations.user_already_in_the_team"); return
      end
      redirect_to team_url(team), notice: I18n.t(".invitations.notice.user_add_to_team"); return
    end
    super
  end

  def after_invite_path_for(resource)
    team_url(Team.find_by(slug: params[:team_id]))
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite, keys: [ :name ])
  end
end
