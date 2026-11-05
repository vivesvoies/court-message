require "test_helper"

class FailOverPhoneLineTest < ActiveSupport::TestCase
  test "fails over the line's queued messages to its active fallback" do
    fallback = create(:phone_line)
    line = create(:gateway_phone_line, fallback_phone_line: fallback)
    message = create(:outbound_message, phone_line: line, outbound_uuid: SecureRandom.uuid)

    run_action(line)

    assert_not(line.reload.active?)
    assert_equal(fallback, message.reload.phone_line)
  end

  test "leaves the line active when its fallback is inactive" do
    line = create(:gateway_phone_line, fallback_phone_line: create(:phone_line, active: false))

    response = run_action(line)

    assert(line.reload.active?)
    assert(response[:messages].any? { |m| m[:type] == :error })
  end

  private

  def run_action(line)
    action = Avo::Actions::FailOverPhoneLine.new
    action.handle(query: [ line ], fields: {}, current_user: nil, resource: nil)
    action.response
  end
end
