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
#  index_conversations_on_contact_id       (contact_id) UNIQUE
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

  before_update :remember_new_last_message
  after_update_commit :broadcast_list_update
  after_rollback :forget_new_last_message

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
    update!(read: true)
  end

  def mark_as_unread!
    update!(read: false)
  end

  def timestamp
    last_message&.updated_at || updated_at
  end

  def title = contact.to_s

  def unread? = !read?

  def status = read? ? "read" : "unread"

  private

  # Only a new message moves a conversation to the top of the lists. Anything
  # else (read, unread, a delivery receipt touching it) refreshes it in place.
  # Deciding on read? instead made a manual "unread" jump to the top, where the
  # open conversation's list marked it read again.
  #
  # A transaction can save the conversation several times before its single
  # commit callback (an inbound SMS sets the last message, then unread), so the
  # new message is remembered until the commit.
  def remember_new_last_message
    @new_last_message = true if last_message_id_changed? && last_message_id.present?
  end

  def forget_new_last_message
    @new_last_message = false
  end

  def broadcast_list_update
    new_last_message = @new_last_message
    forget_new_last_message
    new_last_message ? broadcast_move_to_top : broadcast_refresh
  end

  def broadcast_move_to_top
    # Remove and prepend share a stream: across streams, the prepend could
    # arrive first and its copy be the one removed.
    agent_list_streams.unshift("team_conversations_list_#{team.id}").each do |stream|
      broadcast_remove_to stream
      broadcast_prepend_to stream, partial: "conversations/conversation", locals: { conversation: self }
    end
  end

  def broadcast_refresh
    [ "conversation_list_item_#{id}", *agent_list_streams ].each do |stream|
      broadcast_replace_to stream, partial: "conversations/conversation", locals: { conversation: self }
    end
  end

  def agent_list_streams
    agents.map { |agent| "user_conversations_list_#{agent.id}" }
  end
end
