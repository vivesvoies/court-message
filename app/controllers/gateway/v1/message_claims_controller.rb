# Gateways poll this endpoint to atomically claim outbound messages queued
# on their phone lines. A claimed message that is never acknowledged (via
# Gateway::V1::MessagesController#update) becomes claimable again after
# SmsGateway::CLAIM_TIMEOUT.
module Gateway
  module V1
    class MessageClaimsController < BaseController
      MAX_CLAIM = 50

      def create
        limit = params.fetch(:limit, 10).to_i.clamp(1, MAX_CLAIM)
        # Optional: gateways running one polling process per SIM modem pass
        # the line's number so each process only claims its own messages.
        messages = current_gateway.claim_messages!(limit:, phone: params[:phone])

        render json: {
          messages: messages.includes(:phone_line, conversation: :contact).map { |message| serialize(message) }
        }
      end

      private

      def serialize(message)
        {
          uuid: message.outbound_uuid,
          from: message.phone_line.phone,
          to: message.conversation.contact.phone,
          content: message.content
        }
      end
    end
  end
end
