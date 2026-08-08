# Provide a webhook for message status callbacks from the provider.
class OutboundMessagesController < ApplicationController
  include VonageWebhookAuthentication

  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :set_current
  skip_authorization_check

  wrap_parameters false

  # Statuses the provider is allowed to set through this webhook. Internal
  # statuses (inbound, unsent, deleted) must never come from a callback.
  PROVIDER_STATUSES = %w[submitted delivered rejected undeliverable expired failed].freeze

  def create
    status = params[:status].to_s
    unless PROVIDER_STATUSES.include?(status)
      head :unprocessable_entity
      return
    end

    @message = Message.find_by(outbound_uuid: params[:message_uuid])

    # TODO: Use a queue to fix properly
    if @message.nil?
      Sentry.capture_message("Error OutboundMessagesController, message uuid: #{params[:message_uuid]} not found")
      head :too_early
      return
    end

    @message.status = status

    if @message.save
      head :ok
    else
      head :bad_request
    end
  end
end
