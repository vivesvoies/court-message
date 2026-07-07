# Gateways report per-modem health here every cycle: whether the modem
# responds, signal strength and network registration, or the error that
# broke it. This is what lets monitoring distinguish "Pi down" (stale
# SmsGateway#last_seen_at) from "Pi alive but modem/SIM dead" (modem_ok
# false on the line).
module Gateway
  module V1
    class HeartbeatsController < BaseController
      def create
        line = current_gateway.phone_lines.find_by(phone: PhonyRails.normalize_number(params.require(:phone)))
        return head :not_found unless line

        line.record_modem_check!(ok: modem_ok, details: details)
        head :ok
      end

      private

      def modem_ok
        ActiveModel::Type::Boolean.new.cast(params[:modem_ok])
      end

      def details
        params.permit(details: [ :signal_percent, :network_state, :error ])[:details]
      end
    end
  end
end
