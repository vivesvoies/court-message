class AddPhoneLineToMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :messages, :phone_line, foreign_key: true
    add_column :messages, :claimed_at, :datetime
  end
end
