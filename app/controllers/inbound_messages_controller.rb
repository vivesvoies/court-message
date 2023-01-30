# Provide a webhook for inbound SMS and messages services.
class InboundMessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  wrap_parameters false

  # TODO
  # Verify JWT token from request.headers["HTTP_AUTHORIZATION"]
  # perhaps using https://github.com/jwt/ruby-jwt

  def create
    authenticate_message!
    service = InboundMessagesService.new(vonage_params)
    @message = service.message
    if @message.save
      head :created
    else
      head :bad_request
    end
  end

  private

  def authenticate_message!
    Rails.logger.warn "TODO / Missing authentication of inbound messages."
  end

  def vonage_params
    # Raise ActionController::ParameterMissing if any of those is missing.
    params.require(%i[to from text])

    # Whitelist accepted parameters.
    params.permit(
      [
        :to, :from, :text, :channel, :message_uuid, :timestamp, :message_type,
        { usage: %i[price currency] }, { sms: :num_messages }
      ]
    )
  end
end
