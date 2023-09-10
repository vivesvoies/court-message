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
#  team_id    :bigint           default(2), not null
#
# Indexes
#
#  index_contacts_on_phone              (phone)
#  index_contacts_on_team_id            (team_id)
#  index_contacts_on_team_id_and_phone  (team_id,phone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#
class Contact < ApplicationRecord
  include Conversationalist
  has_one :conversation, dependent: :destroy
  has_many :messages, as: :sender, dependent: nil # let the Conversation model delete the messages
  belongs_to :team

  phony_normalize :phone
  validates :phone, presence: true, uniqueness: { scope: :team_id }, phony_plausible: true

  validates :email, uniqueness: { scope: :team_id }, allow_blank: true

  def formatted_phone
    phone.phony_formatted(format: :national)
  end
end
