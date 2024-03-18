class AddLastMessageToConversations < ActiveRecord::Migration[7.1]
  def change
    add_reference :conversations, :last_message, null: true, foreign_key: { to_table: :messages }
  end
end
