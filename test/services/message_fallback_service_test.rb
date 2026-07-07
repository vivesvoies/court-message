require "test_helper"

class MessageFallbackServiceTest < ActiveSupport::TestCase
  def setup
    @gateway = create(:sms_gateway)
    @fallback = create(:phone_line)
    @line = create(:gateway_phone_line, sms_gateway: @gateway, fallback_phone_line: @fallback, fallback_after_minutes: 15)
    @conversation = create(:conversation)
  end

  def test_fails_over_unclaimed_messages_past_the_deadline
    message = create(:outbound_message, conversation: @conversation, phone_line: @line,
                     outbound_uuid: SecureRandom.uuid, created_at: 20.minutes.ago)

    results = MessageFallbackService.new.run!

    assert_equal([ message ], results.map(&:message))
    assert(results.first.submitted)
    message.reload
    assert_equal(@fallback, message.phone_line)
    # In test env the fallback goes through DummyProvider and is submitted.
    assert(message.submitted_status?)
    assert_equal(@line.phone, message.provider_info.dig("fallback", "from"))
    assert_equal(@fallback.phone, message.provider_info.dig("fallback", "to"))
  end

  def test_ignores_messages_within_the_deadline
    create(:outbound_message, conversation: @conversation, phone_line: @line,
           outbound_uuid: SecureRandom.uuid, created_at: 5.minutes.ago)

    assert_empty(MessageFallbackService.new.run!)
  end

  def test_ignores_lines_without_automatic_fallback
    @line.update!(fallback_after_minutes: nil)
    create(:outbound_message, conversation: @conversation, phone_line: @line,
           outbound_uuid: SecureRandom.uuid, created_at: 1.hour.ago)

    assert_empty(MessageFallbackService.new.run!)
  end

  def test_fails_over_immediately_when_the_line_is_inactive
    @line.update!(fallback_after_minutes: nil, active: false)
    message = create(:outbound_message, conversation: @conversation, phone_line: @line,
                     outbound_uuid: SecureRandom.uuid)

    results = MessageFallbackService.new.run!

    assert_equal([ message ], results.map(&:message))
    assert_equal(@fallback, message.reload.phone_line)
  end

  def test_does_not_touch_claimed_messages
    create(:outbound_message, conversation: @conversation, phone_line: @line,
           outbound_uuid: SecureRandom.uuid, created_at: 1.hour.ago, claimed_at: 30.minutes.ago)

    assert_empty(MessageFallbackService.new.run!)
  end

  def test_retries_modem_failed_messages
    message = create(:outbound_message, conversation: @conversation, phone_line: @line,
                     outbound_uuid: SecureRandom.uuid, claimed_at: 5.minutes.ago, status: :failed)

    results = MessageFallbackService.new.run!

    assert_equal([ message ], results.map(&:message))
    assert(message.reload.submitted_status?)
    assert_equal(@fallback, message.phone_line)
  end

  def test_does_not_fail_over_twice
    create(:outbound_message, conversation: @conversation, phone_line: @line,
           outbound_uuid: SecureRandom.uuid, created_at: 1.hour.ago,
           provider_info: { "fallback" => { "from" => @line.phone } })

    assert_empty(MessageFallbackService.new.run!)
  end

  def test_does_nothing_when_the_fallback_line_is_inactive
    @fallback.update!(active: false)
    create(:outbound_message, conversation: @conversation, phone_line: @line,
           outbound_uuid: SecureRandom.uuid, created_at: 1.hour.ago)

    assert_empty(MessageFallbackService.new.run!)
  end

  def test_can_be_scoped_to_specific_lines
    other_fallback = create(:phone_line)
    other_line = create(:gateway_phone_line, sms_gateway: @gateway, fallback_phone_line: other_fallback, fallback_after_minutes: 15)
    mine = create(:outbound_message, conversation: @conversation, phone_line: @line,
                  outbound_uuid: SecureRandom.uuid, created_at: 1.hour.ago)
    create(:outbound_message, conversation: @conversation, phone_line: other_line,
           outbound_uuid: SecureRandom.uuid, created_at: 1.hour.ago)

    results = MessageFallbackService.new([ @line ]).run!

    assert_equal([ mine ], results.map(&:message))
  end
end
