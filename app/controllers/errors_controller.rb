class ErrorsController < ApplicationController
  skip_authorization_check only: [ :forbidden, :not_found, :unprocessable, :internal_server ]

  def forbidden
    render status: 403
  end

  def not_found
    render status: 404
  end

  def unprocessable
    render status: 422
  end

  def internal_server
    render status: 500
  end
end
