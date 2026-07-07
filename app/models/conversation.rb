# == Schema Information
#
# Table name: conversations
#
#  id              :bigint           not null, primary key
#  read            :boolean          default(TRUE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  contact_id      :bigint           not null
#  last_message_id :bigint
#
# Indexes
#
#  index_conversations_on_contact_id       (contact_id)
#  index_conversations_on_last_message_id  (last_message_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (last_message_id => messages.id)
#
class Conversation < ApplicationRecord
  belongs_to :contact
  has_one :team, through: :contact
  has_many :messages, -> { order(created_at: :asc) }, dependent: :destroy
  has_and_belongs_to_many :agents, class_name: "User"

  belongs_to :last_message, class_name: "Message", optional: true

  after_update_commit :broadcast_conversation_update

  scope :for_team, ->(team) {
                     includes({ contact: :team }, :last_message).where(contacts: { team_id: team.id }).order(Arel.sql("COALESCE(messages.updated_at, conversations.updated_at) DESC"))
                   }

  scope :for_user, ->(user, team) {
                    includes({ contact: :team }, :last_message).where(contacts: { team_id: team.id }, id: user.conversation_ids).order(Arel.sql("COALESCE(messages.updated_at, conversations.updated_at) DESC"))
                  }

  def self.find_preloaded(id)
    includes({ messages: :sender }, :contact, :agents).find(id)
  end

  def mark_as_read!
    update!(read: true, unread_count: 0)
  end

  # Read state is shared by the whole team: one member reading a conversation
  # marks it read (and resets the count) for everyone.
  def mark_as_unread!
    update!(read: false, unread_count: [ unread_count, 1 ].max)
  end

  # The last outbound message could not be delivered; the list shows a
  # warning instead of the unread badge.
  def delivery_failed?
    last_message.present? && !last_message.inbound_status? &&
      (last_message.failed_status? || last_message.expired_status? ||
       last_message.rejected_status? || last_message.undeliverable_status?)
  end

  def timestamp
    last_message&.updated_at || updated_at
  end

  def title = contact.to_s

  def unread? = !read?

  def status = read? ? "read" : "unread"

  private

  # The _later variants render and deliver outside the request cycle: with
  # several agents on a conversation, rendering a partial per subscriber
  # inline would block the response.
  def broadcast_conversation_update
    if unread? # broadcast a new message
      broadcast_remove_to "team_conversations_list_#{team.id}"
      broadcast_prepend_later_to "team_conversations_list_#{team.id}", partial: "conversations/conversation", locals: { conversation: self }
      agents.each do |agent|
        broadcast_remove_to "user_conversations_list_#{agent.id}"
        broadcast_prepend_later_to "user_conversations_list_#{agent.id}", partial: "conversations/conversation", locals: { conversation: self }
      end
    else # broadcast another update (such as change in read / unread status)
      broadcast_replace_later_to "conversation_list_item_#{id}", partial: "conversations/conversation", locals: { conversation: self }
      agents.each do |agent|
        broadcast_replace_later_to "user_conversations_list_#{agent.id}", partial: "conversations/conversation", locals: { conversation: self }
      end
    end
  end
end
