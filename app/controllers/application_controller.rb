class ApplicationController < ActionController::Base
  before_action :set_current
  before_action :authenticate_user!

  private

  def set_current
    Current.user = current_user
    Current.phone_number = "33644639777"
  end
end
