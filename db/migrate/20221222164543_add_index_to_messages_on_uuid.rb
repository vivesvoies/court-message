class AddIndexToMessagesOnUuid < ActiveRecord::Migration[7.0]
  def change
    add_index :messages, :outbound_uuid
  end
end
