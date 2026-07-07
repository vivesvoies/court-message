# == Schema Information
#
# Table name: templates
#
#  id         :bigint           not null, primary key
#  content    :text
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint
#  user_id    :bigint
#
# Indexes
#
#  index_templates_on_team_id  (team_id)
#  index_templates_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#

class Template < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :team, optional: true

  validates :content, presence: true
  # Personal templates (team_id nil) still need an owner; team-shared
  # templates may end up without one once their creator's account is
  # removed (see User#release_shared_templates).
  validates :user, presence: true, unless: :team_id?

  scope :personal, -> { where(team_id: nil) }
  scope :shared, -> { where.not(team_id: nil) }

  def shared?
    team_id.present?
  end
end
