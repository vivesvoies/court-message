class UsersController < ApplicationController
  before_action :set_user, only: %i[ show edit update destroy ]
  authorize_resource

  def index
    @users = User.all
  end

  def show

  end

  def edit

  end

  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to user_url(@user), notice: t(".user_updated") }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @user.destroy
    redirect_to users_url, notice: I18n.t(".user_destroyed"), status: :see_other
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    params.require(:user).permit(:name, :email, :role)
  end
end
