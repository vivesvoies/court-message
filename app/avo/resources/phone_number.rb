class Avo::Resources::PhoneNumber < Avo::BaseResource
  self.includes = []

  def fields
    field :id, as: :id
    field :number, as: :text
    field :label, as: :text
    field :created_at,
      as: :date,
      format: "yyyy-LL-dd"
    field :updated_at,
      as: :date,
      format: "yyyy-LL-dd"
    if view.show?
      field :teams, as: :has_many, visible: -> { resource.record.teams.any? }
    end
  end
end
