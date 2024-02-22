# == Schema Information
#
# Table name: contacts
#
#  id               :bigint           not null, primary key
#  email            :string
#  name             :string
#  notes            :string
#  notes_updated_at :datetime
#  notes_updated_by :bigint
#  phone            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
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
  has_one :conversation, dependent: :destroy, touch: true
  has_many :messages, as: :sender, dependent: nil # let the Conversation model delete the messages
  belongs_to :team

  phony_normalize :phone
  validates :phone, presence: true, uniqueness: { scope: :team_id }, phony_plausible: true

  validates :email, uniqueness: { scope: :team_id }, allow_blank: true

  after_update :update_notes_information

  def formatted_phone
    phone.phony_formatted(format: :national)
  end

  def update_notes_information
    if notes_changed?
      self.notes_updated_at = Time.current
      self.notes_updated_by = Current.user.id if Current.user
    end
  end
end
