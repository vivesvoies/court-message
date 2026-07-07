class AddPhoneLineToTeams < ActiveRecord::Migration[8.1]
  def change
    add_reference :teams, :phone_line, foreign_key: true
  end
end
