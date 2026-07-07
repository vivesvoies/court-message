require "test_helper"

class SmsGatewayTest < ActiveSupport::TestCase
  test "provision! creates a gateway and returns a usable token" do
    gateway, token = SmsGateway.provision!(name: "raspi-mediation")

    assert(gateway.persisted?)
    assert(token.present?)
    assert_not_equal(token, gateway.token_digest)
    assert_equal(gateway, SmsGateway.authenticate_by_token(token))
  end

  test "authenticate_by_token rejects unknown and blank tokens" do
    SmsGateway.provision!(name: "raspi-mediation")

    assert_nil(SmsGateway.authenticate_by_token("wrong-token"))
    assert_nil(SmsGateway.authenticate_by_token(""))
    assert_nil(SmsGateway.authenticate_by_token(nil))
  end

  test "rotate_token! invalidates the previous token" do
    gateway, token = SmsGateway.provision!(name: "raspi-mediation")
    new_token = gateway.rotate_token!

    assert_nil(SmsGateway.authenticate_by_token(token))
    assert_equal(gateway, SmsGateway.authenticate_by_token(new_token))
  end

  test "name must be unique" do
    create(:sms_gateway, name: "raspi-1")

    assert_raises(ActiveRecord::RecordInvalid) { create(:sms_gateway, name: "raspi-1") }
  end

  test "claim_messages! claims queued messages on the gateway's lines" do
    gateway = create(:sms_gateway)
    line = create(:gateway_phone_line, sms_gateway: gateway)
    conversation = create(:conversation)
    older = create(:outbound_message, conversation:, phone_line: line, outbound_uuid: SecureRandom.uuid, created_at: 2.minutes.ago)
    newer = create(:outbound_message, conversation:, phone_line: line, outbound_uuid: SecureRandom.uuid)

    claimed = gateway.claim_messages!

    assert_equal([ older, newer ], claimed.to_a)
    assert(claimed.all? { |message| message.claimed_at.present? })
    assert_empty(gateway.claim_messages!, "already-claimed messages must not be claimed twice")
  end

  test "claim_messages! ignores other gateways, other statuses and unassigned messages" do
    gateway = create(:sms_gateway)
    create(:gateway_phone_line, sms_gateway: gateway)
    other_gateway = create(:sms_gateway)
    other_line = create(:gateway_phone_line, sms_gateway: other_gateway)
    conversation = create(:conversation)

    create(:outbound_message, conversation:, phone_line: other_line, outbound_uuid: SecureRandom.uuid)
    create(:outbound_message, conversation:, outbound_uuid: SecureRandom.uuid) # no phone line
    create(:outbound_message, conversation:, phone_line: other_line, outbound_uuid: SecureRandom.uuid, status: :submitted)

    assert_empty(gateway.claim_messages!)
    assert_equal(1, other_gateway.claim_messages!.count)
  end

  test "claim_messages! re-claims stale claims" do
    gateway = create(:sms_gateway)
    line = create(:gateway_phone_line, sms_gateway: gateway)
    conversation = create(:conversation)
    stale = create(:outbound_message, conversation:, phone_line: line, outbound_uuid: SecureRandom.uuid,
                   claimed_at: (SmsGateway::CLAIM_TIMEOUT + 1.minute).ago)
    fresh = create(:outbound_message, conversation:, phone_line: line, outbound_uuid: SecureRandom.uuid,
                   claimed_at: 1.minute.ago)

    claimed = gateway.claim_messages!

    assert_includes(claimed, stale)
    assert_not_includes(claimed, fresh)
  end

  test "claim_messages! skips messages still missing their outbound uuid" do
    gateway = create(:sms_gateway)
    line = create(:gateway_phone_line, sms_gateway: gateway)
    conversation = create(:conversation)
    # Persisted mid-request, before submit! assigned the uuid: not claimable.
    create(:outbound_message, conversation:, phone_line: line, outbound_uuid: nil)

    assert_empty(gateway.claim_messages!)
  end

  test "claim_messages! skips inactive lines" do
    gateway = create(:sms_gateway)
    line = create(:gateway_phone_line, sms_gateway: gateway, active: false)
    conversation = create(:conversation)
    create(:outbound_message, conversation:, phone_line: line, outbound_uuid: SecureRandom.uuid)

    assert_empty(gateway.claim_messages!)
  end

  test "cannot be destroyed while it still has phone lines" do
    gateway = create(:sms_gateway)
    create(:gateway_phone_line, sms_gateway: gateway)

    assert_not(gateway.destroy)
    assert(gateway.persisted?)
  end

  test "claim_messages! respects the limit" do
    gateway = create(:sms_gateway)
    line = create(:gateway_phone_line, sms_gateway: gateway)
    conversation = create(:conversation)
    3.times { create(:outbound_message, conversation:, phone_line: line, outbound_uuid: SecureRandom.uuid) }

    assert_equal(2, gateway.claim_messages!(limit: 2).count)
    assert_equal(1, gateway.claim_messages!(limit: 2).count)
  end
end
