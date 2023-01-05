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
FactoryBot.define do
  factory :inbound_message, class: "Message" do
    sender { create(:contact) }
    conversation { sender.build_conversation }
    content { Faker::TvShows::BojackHorseman.tongue_twister }
    status { :inbound }
  end

  factory :outbound_message, class: "Message" do
    sender { create(:user) }
    conversation
    content { Faker::TvShows::BojackHorseman.tongue_twister }
  end
end
