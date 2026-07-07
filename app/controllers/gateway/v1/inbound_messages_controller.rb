# Gateways push SMS received on their SIM cards here. Mirrors the public
# InboundMessagesController (Vonage webhook) but is authenticated and uses a
# gateway-shaped payload.
module Gateway
  module V1
    class InboundMessagesController < BaseController
      def create
        service = InboundMessagesService.new(inbound_params, phone_line: receiving_line)
        @message = service.message

        if @message.valid?
          ActiveRecord::Base.transaction do
            @message.save
            @message.conversation.mark_as_unread!
            @message.conversation.messages << @message
          end
        end

        if @message.persisted?
          head :created
        else
          # The sender does not match any Contact (or the payload is invalid):
          # acknowledge with an error the gateway should not retry.
          head :unprocessable_entity
        end
      end

      private

      def inbound_params
        # Raise ActionController::ParameterMissing if any of those is missing.
        params.require(%i[from text])

        params.permit(:to, :from, :text, :received_at, :modem_message_id)
          .merge(channel: "sms", sms_gateway: current_gateway.name)
      end

      # The SIM/line the SMS arrived on, matched by the "to" number when the
      # gateway provides it.
      def receiving_line
        return nil if params[:to].blank?

        current_gateway.phone_lines.find_by(phone: PhonyRails.normalize_number(params[:to]))
      end
    end
  end
end
