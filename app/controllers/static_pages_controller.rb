class StaticPagesController < ApplicationController
  skip_authorization_check only: [ :legal_notice, :terms_and_conditions, :ui ]
  skip_before_action :authenticate_user!, only: [ :legal_notice, :terms_and_conditions ]

  def legal_notice
  end

  def terms_and_conditions
  end

  def ui
    @icons = Dir.glob("app/assets/images/icons/*").map { |f| File.basename(f, File.extname(f)) }
    flash.now[:notice] = "This is a notice with auto-remove" # rubocop:disable Rails/I18nLocaleTexts
  end
end
