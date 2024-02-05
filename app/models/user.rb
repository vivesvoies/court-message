# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :enum             default("user"), not null
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  ROLES = %w[
    user
    team_admin
    site_admin
    super_admin
  ].freeze
  enum :role, ROLES.map { |role| [ role.to_sym, role ] }.to_h, suffix: true

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :confirmable

  include Conversationalist

  # WARN / TODO - make it clear that deleting a user deletes their messages.
  has_many :messages, as: :sender, dependent: :destroy
  has_and_belongs_to_many :conversations

  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships

  def at_least?(role)
    ROLES.index(role.to_s) <= ROLES.index(self.role)
  end

  def bestowable_roles
    ROLES[0..ROLES.index(role)]
  end
end
