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
# Indexes
#
#  index_contacts_on_phone  (phone) UNIQUE
#
class Contact < ApplicationRecord
  include Conversationalist
  has_one :conversation, dependent: :destroy
  has_many :messages, as: :sender, dependent: nil # let the Conversation model delete the messages

  phony_normalize :phone
  validates :phone, presence: true, uniqueness: true, phony_plausible: true

  validates :email, uniqueness: true, allow_blank: true

  def formatted_phone
    phone.phony_formatted(format: :national)
  end
end
