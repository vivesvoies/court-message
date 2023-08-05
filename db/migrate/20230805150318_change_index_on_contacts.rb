class ChangeIndexOnContacts < ActiveRecord::Migration[7.0]
  def change
    # remove uniqueness constraints
    remove_index :contacts, :phone
    add_index :contacts, :phone

    add_index :contacts, [:team_id, :phone], unique: true
  end
end
