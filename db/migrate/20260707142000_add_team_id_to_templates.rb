class AddTeamIdToTemplates < ActiveRecord::Migration[8.1]
  def change
    add_reference :templates, :team, null: true, foreign_key: true, index: true

    # user_id remains the creator, but a team-shared template must survive
    # its creator's account being deleted, so it can no longer be required.
    change_column_null :templates, :user_id, true
  end
end
