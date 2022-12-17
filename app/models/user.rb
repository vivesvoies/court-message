# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  email      :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class User < ApplicationRecord
  include Conversationalist

  # WARN - make it clear that deleting a user deletes their messages.
  has_many :messages, as: :sender, dependent: :destroy
  has_and_belongs_to_many :conversations
end
