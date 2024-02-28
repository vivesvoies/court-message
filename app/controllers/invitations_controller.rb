class InvitationsController < Devise::InvitationsController
  before_action :configure_permitted_parameters

  def create
    user = User.find_by_email(invite_params[:email].strip)
    team = Team.find(invite_params[:team_ids].first.to_i)
    if user
      if user.team_ids.include?(team.id)
        redirect_to team_url(team), notice: I18n.t("devise.invitations.user_already_in_the_team")
      else
        Membership.create(team: Team.find(invite_params[:team_ids].first), user: User.find_by_email(invite_params[:email]))
      end
    else
      super
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:invite, keys: [ :name, :team_ids ])
  end
end
