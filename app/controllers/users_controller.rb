class UsersController < ApplicationController
  before_action :set_team, only: %i[ edit ]
  before_action :set_user, only: %i[ show edit update destroy ]

  authorize_resource :team
  authorize_resource

  # GET /teams/1/users/1
  def show
  end

  # GET /teams/1/users/1/edit
  def edit
  end

  # PATCH/PUT /teams/1/users/1
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to team_url(@team), notice: I18n.t("users.update.user_updated") }
        format.turbo_stream
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@user) }
      end
    end
  end

  # DELETE /teams/1/users/1
  def destroy
    @user.destroy
    redirect_to team_url(@team.id), notice: I18n.t("users.destroy.user_destroyed"), status: :see_other
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_team
    @team = Current.team || Team.find_by(slug: params[:team_id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    params.require(:user).permit(:name, :email, :phone) # removed :role, as we'd need to check for :role <= Current.user.role first
  end
end
