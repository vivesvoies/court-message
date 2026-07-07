require "test_helper"

class InboundMessagesServiceTest < ActiveSupport::TestCase
  def test_creates_message
    contact = create(:contact)
    params = { to: "our phone number", from: contact.phone, text: "Hello" }

    message = InboundMessagesService.new(params).message

    message.save
    assert(message.persisted?)
    assert(message.inbound_status?)
    assert_equal(message.conversation, contact.conversation)
  end

  def test_creates_message_contact_and_convo
    params = { to: "our phone number", from: fake_number, text: "Coucou" }
    message = InboundMessagesService.new(params).message

    contact = message.sender
    assert_nil(contact)

    message.save
    assert_not(message.persisted?)
  end

  def test_finds_the_correct_contact
    contact = create(:contact)
    phone = contact.phone.phony_formatted(national: true)
    params = { to: "our phone number", from: phone, text: "Hello" }

    message = InboundMessagesService.new(params).message

    message.save
    assert(message.persisted?)
    assert(message.inbound_status?)
    assert_equal(message.conversation, contact.conversation)
  end

  # When the number we received on maps to a PhoneNumber, only contacts whose
  # team uses that number are eligible.
  def test_restricts_candidates_to_teams_using_the_receiving_number
    number = create(:phone_number)
    other_number = create(:phone_number)
    team = create(:team, phone_number: number)
    other_team = create(:team, phone_number: other_number)

    phone = fake_number
    contact = create(:contact, phone:, team:)
    create(:contact, phone:, team: other_team)

    params = { to: number.number, from: phone, text: "Hello" }
    message = InboundMessagesService.new(params).message

    assert_equal(contact, message.sender)
  end

  # Two teams share one number and both have the same contact phone: the
  # message must land in the conversation of the team that most recently SENT
  # an outbound (User) message to that person.
  def test_routes_to_team_that_last_wrote_to_the_contact
    number = create(:phone_number)
    team_a = create(:team, phone_number: number)
    team_b = create(:team, phone_number: number)

    phone = fake_number
    contact_a = create(:contact, phone:, team: team_a)
    contact_b = create(:contact, phone:, team: team_b)

    convo_a = contact_a.create_conversation!
    convo_b = contact_b.create_conversation!

    # team_b wrote most recently, so inbound should route to contact_b.
    create(:outbound_message, conversation: convo_a, created_at: 2.days.ago)
    create(:outbound_message, conversation: convo_b, created_at: 1.hour.ago)

    params = { to: number.number, from: phone, text: "Hello" }
    message = InboundMessagesService.new(params).message

    assert_equal(contact_b, message.sender)
    assert_equal(convo_b, message.conversation)
  end

  # Same setup, other team is the most recent writer -> routes there.
  def test_routes_to_the_other_team_when_it_wrote_last
    number = create(:phone_number)
    team_a = create(:team, phone_number: number)
    team_b = create(:team, phone_number: number)

    phone = fake_number
    contact_a = create(:contact, phone:, team: team_a)
    contact_b = create(:contact, phone:, team: team_b)

    convo_a = contact_a.create_conversation!
    convo_b = contact_b.create_conversation!

    create(:outbound_message, conversation: convo_a, created_at: 1.hour.ago)
    create(:outbound_message, conversation: convo_b, created_at: 2.days.ago)

    params = { to: number.number, from: phone, text: "Hello" }
    message = InboundMessagesService.new(params).message

    assert_equal(contact_a, message.sender)
    assert_equal(convo_a, message.conversation)
  end

  # An unknown `to` number keeps the historical behaviour: every matching
  # contact is a candidate (no team restriction).
  def test_unknown_to_number_keeps_all_candidates
    contact = create(:contact)
    params = { to: "not provisioned", from: contact.phone, text: "Hello" }

    message = InboundMessagesService.new(params).message

    assert_equal(contact, message.sender)
  end

  def test_unknown_from_yields_invalid_message
    number = create(:phone_number)
    params = { to: number.number, from: fake_number, text: "Hello" }

    message = InboundMessagesService.new(params).message

    assert_nil(message.sender)
    assert_not(message.valid?)
  end
end
