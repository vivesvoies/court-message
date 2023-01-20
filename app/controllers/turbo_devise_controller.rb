# frozen_string_literal: true

# This code was copy-pasted (:sigh:) from https://gorails.com/episodes/devise-hotwire-turbo.
# Other instructions found at https://betterprogramming.pub/devise-auth-setup-in-rails-7-44240aaed4be.
# Will probably become obsolete in a future Devise update.
#
# See https://github.com/heartcombo/devise/issues/5446
# and https://github.com/heartcombo/devise/pull/5545

class TurboDeviseController < ApplicationController
  class Responder < ActionController::Responder
    def to_turbo_stream
      controller.render(options.merge(formats: :html))
    rescue ActionView::MissingTemplate => error
      if get?
        raise error
      elsif has_errors? && default_action
        render rendering_options.merge(formats: :html, status: :unprocessable_entity)
      else
        redirect_to navigation_location
      end
    end
  end

  self.responder = Responder
  respond_to :html, :turbo_stream
end
