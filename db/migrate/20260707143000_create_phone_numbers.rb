# Introduces PhoneNumber records so teams can own their sending number
# (issues #35 / #54). The end goal is one team = one number, but for now a
# single number may be SHARED by several teams, so teams.phone_number_id is a
# plain nullable FK (no uniqueness) and PhoneNumber has_many :teams.
#
# Data migration: create a PhoneNumber from the configured global outbound
# number and back-fill it onto every existing team, so nothing changes for
# current teams — they keep sending from (and receiving on) the shared number.
class CreatePhoneNumbers < ActiveRecord::Migration[8.1]
  def up
    create_table :phone_numbers do |t|
      # Stored E.164 without the leading "+", matching how the app already
      # stores numbers (e.g. "33644635900").
      t.string :number, null: false
      t.string :label

      t.timestamps
    end
    add_index :phone_numbers, :number, unique: true

    add_reference :teams, :phone_number, null: true, foreign_key: true, index: true

    configured_number = Rails.configuration.x.outbound_phone_number
    if configured_number.present?
      execute(<<~SQL)
        INSERT INTO phone_numbers (number, label, created_at, updated_at)
        VALUES (#{quote(configured_number)}, 'Numéro partagé', NOW(), NOW())
      SQL

      execute(<<~SQL)
        UPDATE teams
        SET phone_number_id = (SELECT id FROM phone_numbers WHERE number = #{quote(configured_number)})
      SQL
    end
  end

  def down
    remove_reference :teams, :phone_number, foreign_key: true
    drop_table :phone_numbers
  end
end
