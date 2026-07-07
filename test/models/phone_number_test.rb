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

require "test_helper"

class PhoneNumberTest < ActiveSupport::TestCase
  def test_factory_is_valid
    assert(create(:phone_number).valid?)
  end

  def test_number_required
    assert_not(build(:phone_number, number: nil).valid?)
  end

  def test_number_unique
    create(:phone_number, number: "33611112222")
    assert_raise(ActiveRecord::RecordInvalid) do
      create(:phone_number, number: "33611112222")
    end
  end

  def test_to_s_returns_the_number
    number = build(:phone_number, number: "33633334444")
    assert_equal("33633334444", number.to_s)
  end

  def test_can_be_shared_by_several_teams
    number = create(:phone_number)
    team_a = create(:team, phone_number: number)
    team_b = create(:team, phone_number: number)

    assert_equal([ team_a, team_b ].sort_by(&:id), number.teams.order(:id).to_a)
  end
end
