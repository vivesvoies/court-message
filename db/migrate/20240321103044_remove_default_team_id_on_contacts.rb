class RemoveDefaultTeamIdOnContacts < ActiveRecord::Migration[7.1]
  def change
    change_column_default :contacts, :team_id, from: 2, to: nil
  end
end
