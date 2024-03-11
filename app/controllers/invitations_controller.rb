class InvitationsController < Devise::InvitationsController
  before_action :configure_permitted_parameters

  def create
    team = Team.find_by(slug: params[:team_id])
    user = User.find_by_email(invite_params[:email].strip)
    if user && user.team_ids.include?(team.id)
      redirect_to team_url(team), notice: I18n.t("devise.invitations.user_already_in_the_team")
    # If the user is already confirmed and in a team, no invitation
    # is sent and the user is automatically added to the team
    elsif user && !user.team_ids.empty? && !user.confirmed_at.nil?
      Membership.create(team: Team.find(team.id), user: User.find(invite_resource.id))
    else
      super
    end
  end

  def after_invite_path_for(resource)
    team_url(Team.find_by(slug: params[:team_id]))
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite, keys: [ :name ])
  end
end
