# This class is responsible for parsing inbound requests
# and creating Message objects.
# If no contact is found, will not create it.
#
# Routing: a single PhoneNumber may be shared by several teams (see #35/#54),
# so the same contact phone can exist in several teams. We narrow candidates to
# the teams that use the number the SMS was received on (`to`), then, when the
# person still exists in several of those teams, route best-effort to the team
# that most recently WROTE to them.
#
# TODO: Currently only supports SMS through Vonage.
# TODO: Notify of inbound messages that don't have a corresponding Contact
class InboundMessagesService
  attr_reader :message

  def initialize(params)
    @params = params
    @from = PhonyRails.normalize_number(params[:from])
    @to = params[:to]

    sender = pick_contact(candidate_contacts)
    conversation = sender&.conversation || sender&.build_conversation
    content = params[:text]

    @message = Message.new(sender:, conversation:, content:, provider_info: params, status: :inbound)
  end

  private

  # Contacts whose phone matches the sender. When the number we received on
  # (`to`) is a known PhoneNumber, only contacts whose team uses that number
  # are eligible; when `to` is unknown (e.g. a number not yet provisioned) we
  # keep every match, preserving the historical behaviour.
  def candidate_contacts
    contacts = Contact.where(phone: @from)
    number = receiving_phone_number
    return contacts unless number

    contacts.where(team_id: number.team_ids)
  end

  def receiving_phone_number
    return nil if @to.blank?

    PhoneNumber.find_by(number: @to) ||
      PhoneNumber.find_by(number: PhonyRails.normalize_number(@to))
  end

  # Best-effort routing when the same phone belongs to a contact in several
  # teams sharing a number: prefer the team that most recently WROTE to this
  # person, then progressively weaker signals.
  def pick_contact(contacts)
    contacts = contacts.to_a
    return contacts.first if contacts.size <= 1

    contacts.max_by { |contact| routing_key(contact) }
  end

  # Ordered from strongest to weakest signal; compared as a tuple so later
  # signals only break ties left by the earlier ones. Times are reduced to a
  # numeric epoch (0.0 when absent) so the comparison never trips over nil.
  def routing_key(contact)
    conversation = contact.conversation
    [
      epoch(last_outbound_message_at(conversation)),
      epoch(last_message_at(conversation)),
      epoch(conversation&.updated_at),
      epoch(contact.created_at)
    ]
  end

  def last_outbound_message_at(conversation)
    conversation&.messages&.where(sender_type: "User")&.maximum(:created_at)
  end

  def last_message_at(conversation)
    conversation&.messages&.maximum(:created_at)
  end

  def epoch(time) = time&.to_f || 0.0
end
