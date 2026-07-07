# Base controller for the SMS gateway API: the endpoints our own SMS
# gateways (SIM modems on devices we control) poll to fetch outbound
# messages, report delivery outcomes and push received SMS.
#
# Authentication: every request must carry "Authorization: Bearer <token>",
# where the token was issued at provisioning time (rake sms_gateway:provision)
# and is stored hashed (SmsGateway#token_digest). Transport security is TLS
# (the app is only reachable over HTTPS); the connection can additionally be
# tunneled through a private network such as Tailscale without any change
# here.
module Gateway
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_gateway!

      private

      attr_reader :current_gateway

      def authenticate_gateway!
        token = request.headers["Authorization"]&.match(/\ABearer (.+)\z/)&.captures&.first
        @current_gateway = SmsGateway.authenticate_by_token(token)

        if @current_gateway
          @current_gateway.touch_last_seen!
        else
          head :unauthorized
        end
      end
    end
  end
end
