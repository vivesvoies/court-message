class AddUnreadCountToConversations < ActiveRecord::Migration[8.1]
  def up
    add_column :conversations, :unread_count, :integer, default: 0, null: false

    # Best effort for existing data: an unread conversation has at least one
    # unread message.
    execute("UPDATE conversations SET unread_count = 1 WHERE read = false")
  end

  def down
    remove_column :conversations, :unread_count
  end
end
