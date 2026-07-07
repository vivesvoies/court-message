class ApplicationController < ActionController::Base
  include FlashHelper
  helper_method :current_frame
  helper_method :turbo_frame_request?
  helper_method :turbo_stream_request?

  before_action :authenticate_user!
  before_action :set_current
  check_authorization unless: :devise_controller?

  private

  class Forbidden < StandardError; end

  unless Rails.env.development?
    rescue_from CanCan::AccessDenied do |_exception|
      render "errors/error", status: 403
    end
  end

  def set_current
    Current.user = current_user

    slug = params[:team_id] || (params[:controller] == "teams" && params[:id])
    Current.team = Team.find_by(slug:) if slug

    # A team can be attached to a specific phone line (Vonage or one of our
    # SMS gateways). Otherwise use the default line, and as a last resort the
    # legacy env-based Vonage number.
    Current.phone_line = Current.team&.phone_line || PhoneLine.default_line
    Current.phone_number = Current.phone_line&.phone || legacy_phone_number
  end

  def legacy_phone_number
    case Rails.env.to_sym
    when :staging
      "33644639777"
    when :production
      "33644635900"
    else
      "33644630057"
    end
  end

  def current_frame
    request&.headers["Turbo-Frame"]
  end

  def turbo_stream_request?
    "text/vnd.turbo-stream.html".in? request&.accept
  end
end
