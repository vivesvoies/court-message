class StaticPagesController < ApplicationController
  skip_authorization_check only: :legal_notice

  def legal_notice
  end
end
