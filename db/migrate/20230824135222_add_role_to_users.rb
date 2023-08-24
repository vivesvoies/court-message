class AddRoleToUsers < ActiveRecord::Migration[7.0]
  def change
    create_enum :user_role, %w[user team_admin site_admin super_admin]
    change_table :users do |t|
      t.enum :role, enum_type: "user_role", default: "user", null: false
    end
  end
end
