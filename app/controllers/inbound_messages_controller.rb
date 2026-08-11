# Provide a webhook for inbound SMS and messages services.
class InboundMessagesController < ApplicationController
  include VonageWebhookAuthentication

  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_before_action :set_current
  skip_authorization_check

  wrap_parameters false

  def create
    service = InboundMessagesService.new(vonage_params)
    @message = service.message

    if @message.valid?
      ActiveRecord::Base.transaction do
        @message.save!
        @message.conversation.mark_as_unread!
      end
    end

    if @message.persisted?
      head :created
    else
      head :bad_request
    end
  end

  private

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
