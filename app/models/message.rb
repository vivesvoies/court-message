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
    undeliverable: "undeliverable"
  }, suffix: true

  belongs_to :conversation, touch: true
  belongs_to :sender, polymorphic: true
  delegate :team, to: :conversation
  after_create :associate_user_with_conversation

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
end
