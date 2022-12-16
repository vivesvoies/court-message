class ApplicationController < ActionController::Base
  before_action :set_user

  private

  def set_user
    Current.user = User.first
  end
end
