class ErrorsController < ApplicationController
  skip_authorization_check only: [ :forbidden, :not_found, :unprocessable, :internal_server ]
  skip_before_action :authenticate_user!, only: [ :forbidden, :not_found, :unprocessable, :internal_server ]

  def forbidden
    render_error_page(:forbidden, 403)
  end

  def not_found
    render_error_page(:not_found, 404)
  end

  def unprocessable
    render_error_page(:unprocessable, 422)
  end

  def internal_server
    render_error_page(:internal_server, 500)
  rescue => e
    render plain: "500 - Erreur interne du serveur", status: 500
  end

  private

  def render_error_page(error_type, status)
    @error_type = error_type
    render "errors/error", status: status
  end
end
