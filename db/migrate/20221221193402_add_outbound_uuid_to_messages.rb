class AddOutboundUuidToMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :messages, :outbound_uuid, :uuid
  end
end
