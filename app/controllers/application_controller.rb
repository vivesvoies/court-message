class ApplicationController < ActionController::Base
  before_action :set_current

  private

  def set_current
    Current.user = User.first
    Current.phone_number = "33644639777"
  end
end
