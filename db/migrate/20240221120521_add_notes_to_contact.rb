class AddNotesToContact < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :notes, :string
    add_column :contacts, :notes_updated_at, :datetime
    add_column :contacts, :notes_updated_by, :bigint
  end
end
