# == Schema Information
#
# Table name: conversations
#
#  id         :bigint           not null, primary key
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
end
