class CreateTeams < ActiveRecord::Migration[7.0]
  def change
    create_table :teams do |t|
      t.text :name, null: false
      t.text :slug, null: false
      t.text :address
      t.text :desc

      t.timestamps
    end

    add_index :teams, :name, unique: true
    add_index :teams, :slug, unique: true
  end
end
