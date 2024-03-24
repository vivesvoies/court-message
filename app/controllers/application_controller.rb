class ApplicationController < ActionController::Base
  include FlashHelper
  helper_method :current_frame
  before_action :authenticate_user!
  before_action :set_current
  check_authorization unless: :devise_controller?

  private

  class Forbidden < StandardError; end

  unless Rails.env.development?
    rescue_from CanCan::AccessDenied do |_exception|
      render plain: "403 / Not authorized", status: :forbidden
    end
  end

  def set_current
    Current.user = current_user
    Current.phone_number = (Rails.env.development? || Rails.env.test?) ? "33644630057" : "33644639777"

    slug = params[:team_id] || (params[:controller] == "teams" && params[:id])
    Current.team = Team.find_by(slug:) if slug
  end

  def current_frame
    request.headers["Turbo-Frame"]
  end
end
