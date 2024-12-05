class ErrorsController < ApplicationController
  skip_authorization_check only: [ :forbidden, :not_found, :unprocessable, :internal_server ]
  skip_before_action :authenticate_user!, only: [ :forbidden, :not_found, :unprocessable, :internal_server ]

  def forbidden
    render "errors/error", status: 403
  end

  def not_found
    render "errors/error", status: 404
  end

  def unprocessable
    render "errors/error", status: 422
  end

  def internal_server
    render "errors/error", status: 500
  rescue => e
    render plain: "500 - Erreur interne du serveur", status: 500
  end
end
