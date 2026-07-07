class CreateSmsGateways < ActiveRecord::Migration[8.1]
  def change
    create_table :sms_gateways do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :sms_gateways, :name, unique: true
    add_index :sms_gateways, :token_digest, unique: true
  end
end
