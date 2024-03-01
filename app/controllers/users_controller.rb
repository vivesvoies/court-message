class UsersController < ApplicationController
  before_action :set_team, only: %i[ index edit update ]
  before_action :set_user, only: %i[ show edit update destroy ]

  authorize_resource :team
  authorize_resource

  # GET /teams/:team_slug/users/new
  def create
  end

  def index
  end

  def show
  end

  # GET /teams/:team_slug/users/:id/edit
  def edit
  end

  # PATCH/PUT /teams/:team_slug/users/:id
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

  def destroy
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_team
    @team = Team.find_by(slug: params[:team_id])
  end

  # Only allow a list of trusted parameters through.
  def user_params
    params.require(:user).permit(:name, :email, :phone) # removed :role, as we'd need to check for :role <= Current.user.role first
  end
end
