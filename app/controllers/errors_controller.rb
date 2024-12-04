class ErrorsController < ApplicationController
  skip_authorization_check only: [ :forbidden, :not_found, :unprocessable, :internal_server ]
  skip_before_action :authenticate_user!, only: [ :forbidden, :not_found, :unprocessable, :internal_server ]

  def forbidden
    render_error_page(403)
  end

  def not_found
    render_error_page(404)
  end

  def unprocessable
    render_error_page(422)
  end

  def internal_server
    render_error_page(500)
  rescue => e
    render plain: "500 - Erreur interne du serveur", status: 500
  end

  private

  def render_error_page(status)
    error_types = {
      403 => :forbidden,
      404 => :not_found,
      422 => :unprocessable,
      500 => :internal_server
    }

    @error_type = error_types[status]
    render "errors/error", status: status
  end
end
