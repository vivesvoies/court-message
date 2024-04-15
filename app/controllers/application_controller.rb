class ApplicationController < ActionController::Base
  include FlashHelper
  helper_method :current_frame
  helper_method :turbo_frame_request?

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
    Current.phone_number = case Rails.env.to_sym
    when :staging
      "33644639777"
    when :production
      "33644635900"
    else
      "33644630057"
    end

    slug = params[:team_id] || (params[:controller] == "teams" && params[:id])
    Current.team = Team.find_by(slug:) if slug
  end

  def current_frame
    request&.headers["Turbo-Frame"]
  end
end
