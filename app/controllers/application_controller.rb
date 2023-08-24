class ApplicationController < ActionController::Base
  include FlashHelper
  before_action :authenticate_user!
  before_action :set_current

  private

  class Forbidden < StandardError; end

  rescue_from Forbidden do |_exception|
    render plain: "403 / Not authorized", status: :forbidden
  end

  def set_current
    Current.user = current_user
    Current.phone_number = "33644639777"

    slug = params[:team_id] || (params[:controller] == "teams" && params[:id])
    Current.team = Team.find_by(slug:) if slug
  end

  def team_member!
    raise Forbidden unless Current.user.is_in?(Current.team)
  end

  def admin_user!
    raise Forbidden unless Current.user.admin?
  end
end
