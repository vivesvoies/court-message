class PagesController < ApplicationController
  skip_authorization_check

  def show
    @icons = Dir.glob("app/assets/images/icons/*").map { |f| File.basename(f, File.extname(f)) }
    flash.now[:notice] = "This is a notice with auto-remove"
    render params[:page]
  end
end
