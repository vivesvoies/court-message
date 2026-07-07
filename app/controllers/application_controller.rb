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
    # legacy env-based Vonage number. Display only — outbound routing derives
    # the line from the message's own team in OutboundMessagesService.
    Current.phone_line = PhoneLine.route_for(Current.team)
    Current.phone_number = Current.phone_line&.phone || PhoneLine.legacy_number
  end

  def current_frame
    request&.headers["Turbo-Frame"]
  end

  def turbo_stream_request?
    "text/vnd.turbo-stream.html".in? request&.accept
  end
end
