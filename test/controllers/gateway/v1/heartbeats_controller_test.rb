require "test_helper"

class Gateway::V1::HeartbeatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @gateway, @token = SmsGateway.provision!(name: "raspi-test")
    @line = create(:gateway_phone_line, sms_gateway: @gateway)
  end

  test "should refuse requests without a token" do
    post gateway_v1_heartbeat_path, params: { phone: @line.phone, modem_ok: true }

    assert_response :unauthorized
  end

  test "should record a healthy modem check" do
    post gateway_v1_heartbeat_path,
         params: { phone: @line.phone, modem_ok: true, details: { signal_percent: 80, network_state: "HomeNetwork" } },
         headers: auth_header

    assert_response :ok
    @line.reload
    assert(@line.modem_ok)
    assert(@line.last_modem_check_at.present?)
    assert_equal(80, @line.modem_details["signal_percent"].to_i)
  end

  test "should record a broken modem" do
    post gateway_v1_heartbeat_path,
         params: { phone: @line.phone, modem_ok: false, details: { error: "ERR_DEVICENOTEXIST" } },
         headers: auth_header

    assert_response :ok
    @line.reload
    assert_equal(false, @line.modem_ok)
    assert_equal("ERR_DEVICENOTEXIST", @line.modem_details["error"])
  end

  test "should return not found for lines of other gateways" do
    other_line = create(:gateway_phone_line)

    post gateway_v1_heartbeat_path, params: { phone: other_line.phone, modem_ok: true }, headers: auth_header

    assert_response :not_found
  end

  private

  def auth_header
    { "Authorization" => "Bearer #{@token}" }
  end
end
