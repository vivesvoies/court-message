class ApplicationController < ActionController::Base
  include FlashHelper

  before_action :authenticate_user!
  before_action :set_current

  private

  def set_current
    Current.user = current_user
    Current.phone_number = "33644639777"

    slug = params[:team_id] || (params[:controller] == "teams" && params[:id])
    Current.team = Team.find_by(slug:) if slug
  end
  end
end
