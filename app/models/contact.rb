# == Schema Information
#
# Table name: contacts
#
#  id                   :bigint           not null, primary key
#  email                :string
#  name                 :string
#  notes                :text
#  notes_updated_at     :datetime
#  phone                :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  notes_last_editor_id :bigint
#  team_id              :bigint           default(1), not null
#
# Indexes
#
#  index_contacts_on_notes_last_editor_id  (notes_last_editor_id)
#  index_contacts_on_phone                 (phone)
#  index_contacts_on_team_id               (team_id)
#  index_contacts_on_team_id_and_phone     (team_id,phone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (notes_last_editor_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#
class Contact < ApplicationRecord
  include Conversationalist
  has_one :conversation, dependent: :destroy, touch: true
  has_many :messages, as: :sender, dependent: nil # let the Conversation model delete the messages
  belongs_to :team
  belongs_to :notes_last_editor, class_name: "User", optional: true

  phony_normalize :phone
  validates :phone, presence: true, uniqueness: { scope: :team_id }, phony_plausible: true

  validates :email, uniqueness: { scope: :team_id }, allow_blank: true

  before_update :update_notes_information, if: :notes_changed?

  def formatted_phone
    phone.phony_formatted(format: :national)
  end

  private

  def update_notes_information
    self.update_columns(notes_updated_at: Time.current)
    self.update_columns(notes_last_editor_id: Current.user.id) if Current.user
  end
end
