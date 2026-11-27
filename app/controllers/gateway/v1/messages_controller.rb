# Gateways report the outcome of claimed messages here: "submitted" once the
# modem accepted the SMS, "failed" when sending failed, and later the
# network's status report ("delivered", "undeliverable", "expired").
module Gateway
  module V1
    class MessagesController < BaseController
      ALLOWED_STATUSES = %w[submitted delivered failed rejected undeliverable expired].freeze
      # What the network said about delivery. A "submitted" ack retried after
      # one of these (the daemon journals acks) must not undo it.
      FINAL_STATUSES = %w[delivered rejected undeliverable expired].freeze

      def update
        message = current_gateway.messages.find_by(outbound_uuid: params[:id])
        return head :not_found unless message

        status = params.require(:status)
        return head :unprocessable_entity unless ALLOWED_STATUSES.include?(status)
        return head :ok if status == "submitted" && FINAL_STATUSES.include?(message.status)

        code = network_code
        message.provider_info = (message.provider_info || {}).merge("delivery_report" => { "code" => code }) if code
        if message.update(status:)
          head :ok
        else
          head :unprocessable_entity
        end
      end

      private

      # The network's TP-ST value behind a final status (0-255), which says
      # why a message was not delivered. Kept for support, never shown.
      def network_code
        code = Integer(params[:code], exception: false)
        code if code&.between?(0, 255)
      end
    end
  end
end
