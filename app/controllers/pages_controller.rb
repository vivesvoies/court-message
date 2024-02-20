# Display static pages
class PagesController < ApplicationController
  skip_authorization_check

  def show
    @page = params[:id]
    @frame = params[:frame]
    prepare_ui_page if @page == "ui"
    render @page
  rescue ActionView::MissingTemplate
    render "show"
  end

  private

  def prepare_ui_page
    @icons = Dir.glob("app/assets/images/icons/*").map { |f| File.basename(f, File.extname(f)) }
    flash.now[:notice] = "This is a notice with auto-remove" # rubocop:disable Rails/I18nLocaleTexts
  end
end
