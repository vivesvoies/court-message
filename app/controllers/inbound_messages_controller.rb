# Provide a webhook for inbound SMS and messages services.
class InboundMessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
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

  def log_params
    Rails.logger.info "✉️  PARAMS"
    Rails.logger.info vonage_params
    # Rails.logger.info "✉️  HEADERS"
    # request.headers.each do |h|
      # Rails.logger.info h
    # end
    Rails.logger.info "✉️  END MESSAGE"
  end
end

__END__
# Model from Vonage
{
  "to"=>"33644639777",
  "from"=>"33645505205",
  "channel"=>"sms",
  "message_uuid"=>"ba081bbd-da9a-49e6-b845-9a22fa4b5c76",
  "timestamp"=>"2022-12-14T13:11:17Z",
  "usage"=>{
      "price"=>"0.0200",
      "currency"=>"EUR"
  },
  "message_type"=>"text",
  "text"=>"Bonjour bonjour.",
  "sms"=>{
      "num_messages"=>"1"
  },
  "inbound_message"=>{
      "to"=>"33644639777",
      "from"=>"33645505205",
      "channel"=>"sms",
      "message_uuid"=>"ba081bbd-da9a-49e6-b845-9a22fa4b5c76",
      "timestamp"=>"2022-12-14T13:11:17Z",
      "usage"=>{
          "price"=>"0.0200",
          "currency"=>"EUR"
      },
      "message_type"=>"text",
      "text"=>"Bonjour bonjour.",
      "sms"=>{
          "num_messages"=>"1"
      }
  }
}