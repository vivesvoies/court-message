# Provider for phone lines carried by one of our own SMS gateways (a SIM
# modem in a device we control, e.g. a Raspberry Pi).
#
# Gateways are usually behind NAT and never receive connections; instead they
# poll the app (see Gateway::V1 controllers). So "sending" here only assigns
# an outbound UUID and leaves the message queued (status stays "unsent");
# the gateway claims it on its next poll and reports the real outcome
# through PATCH /gateway/v1/messages/:uuid.
class SmsGatewayProvider
  def send(from:, to:, content:)
    ProviderResult.new(success: true, queued: true, message_uuid: SecureRandom.uuid)
  end
end
