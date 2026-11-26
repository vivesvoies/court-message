require "test_helper"

class MessagesHelperTest < ActionView::TestCase
  test "shows the status the provider reported" do
    assert_equal "Envoyé", message_status_label(build(:outbound_message, status: :delivered, claimed_at: Time.current))
    assert_equal "Message non distribué", message_status_label(build(:outbound_message, status: :undeliverable, claimed_at: Time.current))
    assert_equal "Reçu", message_status_label(build(:inbound_message))
  end

  # Vonage reports delivery, so its "submitted" is a step on the way.
  test "shows a Vonage message as being sent" do
    assert_equal "Envoi en cours...", message_status_label(build(:outbound_message, status: :submitted))
  end

  # A SIM gateway message stays "submitted" when no delivery report comes
  # back (all of them before reports were requested): its fate is unknown.
  test "shows nothing for a gateway message whose delivery is unknown" do
    assert_nil message_status_label(build(:outbound_message, status: :submitted, claimed_at: Time.current))
  end

  test "shows nothing for a message still waiting in the queue" do
    assert_nil message_status_label(build(:outbound_message, status: :unsent))
  end
end
