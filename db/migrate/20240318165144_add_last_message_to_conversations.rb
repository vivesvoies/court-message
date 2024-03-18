class AddLastMessageToConversations < ActiveRecord::Migration[7.1]
  def up
    add_reference :conversations, :last_message, null: true, foreign_key: { to_table: :messages }

    Conversation.find_each do |conversation|
      last_message = conversation.messages.last
      conversation.update(last_message: last_message)
    end
  end

  def down
    remove_reference :conversations, :last_message
  end
end
