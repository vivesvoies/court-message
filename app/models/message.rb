# == Schema Information
#
# Table name: messages
#
#  id              :bigint           not null, primary key
#  content         :string
#  outbound_uuid   :uuid
#  provider_info   :jsonb
#  sender_type     :string           not null
#  status          :enum             default("unsent"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :bigint           not null
#  sender_id       :bigint           not null
#
# Indexes
#
#  index_messages_on_conversation_id  (conversation_id)
#  index_messages_on_outbound_uuid    (outbound_uuid)
#  index_messages_on_sender           (sender_type,sender_id)
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => conversations.id)
#
class Message < ApplicationRecord
  enum :status, {
    inbound: "inbound",
    unsent: "unsent",
    submitted: "submitted",
    delivered: "delivered",
    rejected: "rejected",
    undeliverable: "undeliverable",
    expired: "expired",
    failed: "failed",
    deleted: "deleted"
  }, suffix: true

  belongs_to :conversation, touch: true
  belongs_to :sender, polymorphic: true
  delegate :team, to: :conversation
  after_create :associate_user_with_conversation
  after_create :count_unread_inbound, if: :inbound_status?
  after_save :update_conversation_last_message, if: :saved_change_to_conversation_id?
  before_destroy :reassign_conversation_last_message

  validates_presence_of :content

  broadcasts_to :conversation

  def direction
    inbound_status? ? :inbound : :outbound
  end

  private

  def associate_user_with_conversation
    if sender_type == "User"
      conversation.agents << sender unless conversation.agents.include?(sender)
    end
  end

  # No callbacks/broadcast here: the inbound flow marks the conversation
  # unread right after, which broadcasts once with the fresh count.
  def count_unread_inbound
    conversation.increment!(:unread_count)
  end

  # Runs when the message is created or moved into a conversation. When it
  # was moved, the previous conversation must stop pointing at it too.
  def update_conversation_last_message
    old_conversation_id, _new_id = saved_change_to_conversation_id
    detach_last_message_from(Conversation.find_by(id: old_conversation_id)) if old_conversation_id

    conversation.update!(last_message: self)
  end

  # Point the conversation to the previous message (or nothing) before the
  # database sees the delete; destroying a non-last message used to clear
  # Conversation#last_message unconditionally.
  def reassign_conversation_last_message
    detach_last_message_from(conversation)
  end

  def detach_last_message_from(other_conversation)
    return unless other_conversation
    # Check the database, not the possibly stale in-memory attribute.
    return unless Conversation.where(id: other_conversation.id).pick(:last_message_id) == id

    previous = other_conversation.messages.where.not(id: id).reorder(created_at: :desc, id: :desc).first
    other_conversation.update_column(:last_message_id, previous&.id)
  end
end
