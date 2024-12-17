# == Schema Information
#
# Table name: teams
#
#  id         :bigint           not null, primary key
#  address    :text
#  desc       :text
#  name       :text             not null
#  slug       :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_teams_on_name  (name) UNIQUE
#  index_teams_on_slug  (slug) UNIQUE
#

class Team < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :contacts
  has_many :conversations, through: :contacts
  delegate :include?, to: :users

  before_validation :set_slug, if: -> { slug.blank? }
  validates :name, uniqueness: true, presence: true
  validates :slug, uniqueness: true, presence: true

  def to_param
    slug
  end

  # Sugar for CanCanCan
  def team = self

  private

  def set_slug
    self.slug = name.parameterize if name
  end
end
