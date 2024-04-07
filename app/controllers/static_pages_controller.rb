class StaticPagesController < ApplicationController
  skip_authorization_check only: [:legal_notice, :ui]
  skip_before_action :authenticate_user!, only: [:legal_notice]

  def legal_notice
  end

  def ui
    @icons = Dir.glob("app/assets/images/icons/*").map { |f| File.basename(f, File.extname(f)) }
    flash.now[:notice] = "This is a notice with auto-remove" # rubocop:disable Rails/I18nLocaleTexts
  end
end
