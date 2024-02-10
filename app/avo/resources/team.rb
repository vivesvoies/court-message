class Avo::Resources::Team < Avo::BaseResource
    self.includes = []
    self.find_record_method = -> {
          id.to_i == 0 ? query.find_by_slug(id) : query.find(id)
    }

    def fields
        field :id, as: :id, link_to_record: true
        field :name, as: :text
        field :address, as: :text
        field :slug, as: :text, name: "Identifiant unique"
        field :created_at,
            as: :date,
            format: "yyyy-LL-dd"
        if view.show?
            field :updated_at,
            as: :date,
            format: "yyyy-LL-dd"
            field :desc, as: :text
            field :users, as: :has_many, through: :memberships, visible: -> { resource.record.users.any? }
            field :contacts, as: :has_many, visible: -> { resource.record.contacts.any? }
            field :conversations, as: :has_many, through: :contacts, visible: -> { resource.record.contacts.any? }
        end
    end
end
