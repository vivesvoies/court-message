class ApplicationController < ActionController::Base
  include FlashHelper

  before_action :authenticate_user!
  before_action :set_current

  private

  def set_current
    Current.user = current_user
    Current.phone_number = "33644639777"
  end
end
