class AddNotesToContact < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :notes, :text
    add_column :contacts, :notes_updated_at, :datetime
    add_reference(:contacts, :notes_updated_by, foreign_key: { to_table: :users })
  end
end