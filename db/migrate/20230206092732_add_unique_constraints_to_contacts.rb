class AddUniqueConstraintsToContacts < ActiveRecord::Migration[7.0]
  def change
    add_index :contacts, :phone, unique: true
  end
end
