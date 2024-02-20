class Avo::Resources::Contact < Avo::BaseResource
    self.includes = []

    def fields
        field :id, as: :id
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
        end
    end
end
