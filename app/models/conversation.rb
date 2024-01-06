# == Schema Information
#
# Table name: conversations
#
#  id         :bigint           not null, primary key
#  read       :boolean          default(TRUE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  contact_id :bigint           not null
#
# Indexes
#
#  index_conversations_on_contact_id  (contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#
class Conversation < ApplicationRecord
  belongs_to :contact
  has_one :team, through: :contact
  has_many :messages, -> { order(created_at: :asc) }, dependent: :destroy
  has_and_belongs_to_many :agents, class_name: "User"

  after_update_commit :broadcast_conversation_update

  # TODO: eager loading EVERY MESSAGE, this is overkill but needed for now to show the latest messages.
  # Should create a last_message_id column. Use the :after_add option of the has_many method.
  # See https://github.com/louije/court-message/issues/47
  scope :for_team, ->(team) {
                     includes(:messages, contact: :team).where(contacts: { team_id: team.id }).order(updated_at: :desc)
                   }

  def self.find_preloaded(id)
    includes({ messages: :sender }, :contact, :agents).find(id)
  end

  def title
    contact.to_s
  end

  def mark_as_read!
    update!(read: true)
  end

  def mark_as_unread!
    update!(read: false)
  end

  def unread? = !read?

  def status = read? ? "read" : "unread"

  private

  def broadcast_conversation_update
    if unread? # broadcast a new message
      broadcast_remove_to "conversation_list_item_#{id}"
      broadcast_prepend_to "team_conversations_list_#{team.id}", partial: "conversations/conversation", locals: { conversation: self }
    else # broadcast another upddate (such as change in read / unread status)
      broadcast_replace_to "conversation_list_item_#{id}", partial: "conversations/conversation", locals: { conversation: self }
    end
  end
end
