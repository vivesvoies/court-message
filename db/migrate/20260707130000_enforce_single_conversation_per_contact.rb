# A Contact has_one Conversation, but nothing enforced it: creating a
# conversation for a contact that already had one silently produced a
# duplicate. Merge any existing duplicates (keeping the most recently
# updated conversation), then back the association with a unique index.
class EnforceSingleConversationPerContact < ActiveRecord::Migration[8.1]
  def up
    duplicated_contact_ids = select_values(<<~SQL)
      SELECT contact_id FROM conversations GROUP BY contact_id HAVING COUNT(*) > 1
    SQL

    duplicated_contact_ids.each do |contact_id|
      ids = select_values(<<~SQL)
        SELECT id FROM conversations WHERE contact_id = #{contact_id.to_i} ORDER BY updated_at DESC, id DESC
      SQL
      keeper, *duplicates = ids
      duplicate_list = duplicates.join(", ")

      execute("UPDATE messages SET conversation_id = #{keeper} WHERE conversation_id IN (#{duplicate_list})")
      execute(<<~SQL)
        INSERT INTO conversations_users (user_id, conversation_id)
        SELECT DISTINCT user_id, #{keeper} FROM conversations_users
        WHERE conversation_id IN (#{duplicate_list})
        ON CONFLICT DO NOTHING
      SQL
      execute("DELETE FROM conversations_users WHERE conversation_id IN (#{duplicate_list})")
      execute(<<~SQL)
        UPDATE conversations SET last_message_id = (
          SELECT id FROM messages WHERE conversation_id = #{keeper} ORDER BY created_at DESC, id DESC LIMIT 1
        ) WHERE id = #{keeper}
      SQL
      execute("DELETE FROM conversations WHERE id IN (#{duplicate_list})")
    end

    remove_index :conversations, :contact_id
    add_index :conversations, :contact_id, unique: true
  end

  def down
    remove_index :conversations, :contact_id
    add_index :conversations, :contact_id
  end
end
