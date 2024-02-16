class AddNotesToContact < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :notes, :string
  end
end
