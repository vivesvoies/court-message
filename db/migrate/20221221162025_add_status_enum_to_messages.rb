class AddStatusEnumToMessages < ActiveRecord::Migration[7.0]
  def change
    create_enum :message_status, %w[inbound unsent submitted delivered rejected undeliverable]

    change_table :messages do |t|
      t.enum :status, enum_type: "message_status", default: "unsent", null: false
    end
  end
end
