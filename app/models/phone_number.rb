# == Schema Information
#
# Table name: phone_numbers
#
#  id         :bigint           not null, primary key
#  label      :string
#  number     :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_phone_numbers_on_number  (number) UNIQUE
#

# A phone number the app can send from and receive on. For now a single
# PhoneNumber may be shared by several teams (has_many :teams); the end goal is
# one team = one number. Numbers are stored in E.164 without the leading "+"
# (e.g. "33644635900"), matching how contacts store their phone.
class PhoneNumber < ApplicationRecord
  has_many :teams, dependent: :nullify

  validates :number, presence: true, uniqueness: true

  def to_s = number
end
