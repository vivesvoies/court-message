class ApplicationController < ActionController::Base
  include FlashHelper
  before_action :authenticate_user!
  before_action :set_current
  check_authorization unless: :devise_controller?
  
  private
  
  class Forbidden < StandardError; end
  
  rescue_from CanCan::AccessDenied do |_exception|
    render plain: "403 / Not authorized", status: :forbidden
  end unless Rails.env.development?
  
  def set_current
    Current.user = current_user
    Current.phone_number = "33644639777"

    slug = params[:team_id] || (params[:controller] == "teams" && params[:id])
    Current.team = Team.find_by(slug:) if slug
  end
end
