# == Schema Information
#
# Table name: templates
#
#  id         :integer          not null, primary key
#  title      :string
#  content    :text
#  user_id    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_templates_on_user_id  (user_id)
#

class Template < ApplicationRecord
  belongs_to :user

  validates :content, presence: true
end
