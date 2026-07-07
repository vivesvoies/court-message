class AddGatewayIndexesToMessages < ActiveRecord::Migration[8.1]
  def change
    # The claim/health queries poll for queued messages; keep the index tiny.
    add_index :messages, [ :phone_line_id, :created_at ],
      where: "status = 'unsent'", name: "index_messages_on_unsent_claimable"
    # Inbound idempotency lookups (gateway retries after a lost response).
    add_index :messages, "(provider_info->>'modem_message_id')",
      where: "(provider_info->>'modem_message_id') IS NOT NULL",
      name: "index_messages_on_modem_message_id"
  end
end
