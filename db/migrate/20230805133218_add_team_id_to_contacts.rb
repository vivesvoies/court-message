class AddTeamIdToContacts < ActiveRecord::Migration[7.0]
  def change
    add_reference :contacts, :team, null: false, foreign_key: true,
                                    default: Team.find_or_create_by(name: "Default Team").id
  end
end
