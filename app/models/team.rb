# == Schema Information
#
# Table name: teams
#
#  id              :bigint           not null, primary key
#  address         :text
#  desc            :text
#  name            :text             not null
#  slug            :text             not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  phone_number_id :bigint
#
# Indexes
#
#  index_teams_on_name             (name) UNIQUE
#  index_teams_on_phone_number_id  (phone_number_id)
#  index_teams_on_slug             (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (phone_number_id => phone_numbers.id)
#

class Team < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :contacts
  has_many :conversations, through: :contacts
  belongs_to :phone_number, optional: true
  delegate :include?, to: :users

  before_validation :set_slug, if: -> { slug.blank? }
  validates :name, uniqueness: true, presence: true
  validates :slug, uniqueness: true, presence: true

  def to_param
    slug
  end

  # The number this team sends from (and receives on). Falls back to the
  # configured global number so teams without a PhoneNumber keep working while
  # numbers are being provisioned.
  def outbound_number
    phone_number&.number || Rails.configuration.x.outbound_phone_number
  end

  # Sugar for CanCanCan
  def team = self

  private

  def set_slug
    self.slug = name.parameterize if name
  end
end
