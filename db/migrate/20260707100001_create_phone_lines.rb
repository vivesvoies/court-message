class CreatePhoneLines < ActiveRecord::Migration[8.1]
  def change
    create_table :phone_lines do |t|
      t.string :phone, null: false
      t.string :provider, null: false, default: "vonage"
      t.references :sms_gateway, foreign_key: true
      t.boolean :default, null: false, default: false

      t.timestamps
    end

    add_index :phone_lines, :phone, unique: true
    # At most one default line.
    add_index :phone_lines, :default, unique: true, where: '"default" = true', name: "index_phone_lines_on_single_default"
  end
end
