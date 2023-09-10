class RegistrationsController < Devise::RegistrationsController
  def show
  end

  protected

  def after_inactive_sign_up_path_for(resource)
    await_confirmation_path
  end
end