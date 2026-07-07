class AddRoleToMemberships < ActiveRecord::Migration[8.1]
  def up
    create_enum :membership_role, %w[member admin]
    change_table :memberships do |t|
      t.enum :role, enum_type: "membership_role", default: "member", null: false
    end

    # Data migration: preserve the previous global semantics where a
    # `team_admin` user was admin of every team they belonged to.
    # For each such user, promote ALL of their memberships to `admin`,
    # then downgrade the user to the plain `user` global role.
    # `team_admin` stays in the `user_role` enum type but is no longer
    # written by the application (roles on users are now global-only).
    execute(<<~SQL.squish)
      UPDATE memberships
      SET role = 'admin'
      WHERE user_id IN (SELECT id FROM users WHERE role = 'team_admin')
    SQL

    execute(<<~SQL.squish)
      UPDATE users
      SET role = 'user'
      WHERE role = 'team_admin'
    SQL
  end

  def down
    # Best-effort reversal: restore a global team_admin role for users who
    # are admin of at least one membership, then drop the column and enum.
    execute(<<~SQL.squish)
      UPDATE users
      SET role = 'team_admin'
      WHERE id IN (SELECT user_id FROM memberships WHERE role = 'admin')
    SQL

    change_table :memberships do |t|
      t.remove :role
    end
    drop_enum :membership_role
  end
end
