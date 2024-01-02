# Display static pages
class PagesController < ApplicationController
  skip_authorization_check

  def show
    prepare_ui_page if params[:page] == "ui"
    render params[:page]
  end

  private

  def prepare_ui_page
    @icons = Dir.glob("app/assets/images/icons/*").map { |f| File.basename(f, File.extname(f)) }
    flash.now[:notice] = "This is a notice with auto-remove" # rubocop:disable Rails/I18nLocaleTexts
  end
end
