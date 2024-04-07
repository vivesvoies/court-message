class StaticPagesController < ApplicationController
  skip_authorization_check only: :legal_notice
  skip_before_action :authenticate_user!

  def legal_notice
  end
end
