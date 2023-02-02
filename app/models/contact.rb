# == Schema Information
#
# Table name: contacts
#
#  id         :bigint           not null, primary key
#  email      :string
#  name       :string
#  phone      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Contact < ApplicationRecord
  include Conversationalist
  has_one :conversation, dependent: :destroy
  has_many :messages, as: :sender, dependent: nil # let the Conversation model delete the messages

  phony_normalize :phone
  validates_plausible_phone :phone, presence: true

  def formatted_phone
    phone.phony_formatted(format: :national)
  end
end
