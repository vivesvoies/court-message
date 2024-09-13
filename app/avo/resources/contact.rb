class Avo::Resources::Contact < Avo::BaseResource
  self.includes = []

  def fields
    field :id, ad: :id
    field :name, as: :text
    field :email, as: :text
    field :phone, as: :text
    field "team", as: :text do
      record.team.name
    rescue
      false
    end
    field :created_at,
      as: :date,
      format: "yyyy-LL-dd"
    field :updated_at,
      as: :date,
      format: "yyyy-LL-dd"
    if view.show?
      field :team_id, as: :number
      field :notes_updated_at,
        as: :date,
        format: "yyyy-LL-dd"
      field :notes, as: :text
      field :notes_last_editor, as: :text
    end
  end
end
