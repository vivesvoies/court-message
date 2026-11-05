# Gateways report the outcome of claimed messages here: "submitted" once the
# modem accepted the SMS, "failed" when sending failed, and later delivery
# updates if the modem receives delivery reports.
module Gateway
  module V1
    class MessagesController < BaseController
      ALLOWED_STATUSES = %w[submitted delivered failed rejected undeliverable expired].freeze

      def update
        message = current_gateway.messages.find_by(outbound_uuid: params[:id])
        return head :not_found unless message

        status = params.require(:status)
        return head :unprocessable_entity unless ALLOWED_STATUSES.include?(status)

        if message.update(status:)
          head :ok
        else
          head :unprocessable_entity
        end
      end
    end
  end
end
