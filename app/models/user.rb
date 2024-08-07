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
#  invitation_accepted_at :datetime
#  invitation_created_at  :datetime
#  invitation_limit       :integer
#  invitation_sent_at     :datetime
#  invitation_token       :string
#  invitations_count      :integer          default(0)
#  invited_by_type        :string
#  name                   :string
#  phone                  :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :enum             default("user"), not null
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  invited_by_id          :bigint
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_invitation_token      (invitation_token) UNIQUE
#  index_users_on_invited_by            (invited_by_type,invited_by_id)
#  index_users_on_invited_by_id         (invited_by_id)
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
  devise :invitable, :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :confirmable

  include Conversationalist

  # WARN / TODO - make it clear that deleting a user deletes their messages.
  has_many :messages, as: :sender, dependent: :destroy
  has_and_belongs_to_many :conversations

  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships
  has_many :contacts
  has_many :templates, dependent: :destroy

  after_create :add_default_template

  def at_least?(role)
    ROLES.index(role.to_s) <= ROLES.index(self.role)
  end

  def bestowable_roles
    ROLES[0..ROLES.index(role)]
  end

  def is_authorize_on_avo
    self.role == "site_admin" || self.role == "super_admin"
  end

  # TODO: Check if the invitations is still valid
  def awaiting_invitation_reply?
    if confirmed_at.present? && invitation_created_at.nil? || invitation_accepted_at.present?
      return false
    elsif invitation_created_at.present? && invitation_accepted_at.nil?
      return true
    end
    false
  end

  def belongs_to_team?(team)
    memberships.exists?(team_id: team.id)
  end

  def can_be_deleted?
    !confirmed_at.present? && teams.empty? && messages.empty?
  end

  def send_reset_password_instructions
    super if invitation_token.nil?
  end

  private

  def add_default_template
    default_template = Template.create(
      title: I18n.t("activerecord.models.user.default_template.title"),
      content: I18n.t("activerecord.models.user.default_template.content")
    )
    templates << default_template
  end
end
