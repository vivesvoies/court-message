class AddHealthAndFallbackToPhoneLines < ActiveRecord::Migration[8.1]
  def change
    change_table :phone_lines do |t|
      t.boolean :active, null: false, default: true
      t.references :fallback_phone_line, foreign_key: { to_table: :phone_lines }
      # nil = no automatic fallback; a line stuck longer than this is re-routed.
      t.integer :fallback_after_minutes
      t.datetime :last_modem_check_at
      t.boolean :modem_ok
      t.jsonb :modem_details
    end
  end
end
