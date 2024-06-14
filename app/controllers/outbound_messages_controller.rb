class OutboundMessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :set_current
  skip_authorization_check

  wrap_parameters false

  def create
    @message = Message.find_by(outbound_uuid: params[:message_uuid])

    # TODO: Use a queue to fix properly
    if @message.nil?
      Sentry.capture_message("Error OutboundMessagesController, message uuid: #{params[:message_uuid]} not found")
      head :too_early
      return
    end

    @message.status = params[:status]

    if @message.save
      head :ok
    else
      head :bad_request
    end
  end
end
