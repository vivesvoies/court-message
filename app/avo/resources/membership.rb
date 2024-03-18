class Avo::Resources::Membership < Avo::BaseResource
    self.includes = []

    def fields
        field :id, as: :id, link_to_record: true
        field :team, as: :belongs_to
        field :team_id, as: :id
        field :user, as: :belongs_to
        field :user_id, as: :id
        field :created_at,
            as: :date,
            format: "yyyy-LL-dd"
    end
end
