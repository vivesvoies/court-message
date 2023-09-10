class AddReadIndicatorToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :read, :boolean, default: true
  end
end
