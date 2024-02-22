class AddNotesToContact < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :notes, :text
    add_column :contacts, :notes_updated_at, :datetime
    add_column :contacts, :notes_updated_by, :integer
  end
end
