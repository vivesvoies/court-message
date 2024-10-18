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
    field "Total Messages Sent", as: :number do
      record.conversations.joins(:messages).count
    rescue
      0
    end
    field "Total Users", as: :number do
      record.users.count
    rescue
      0
    end
    field "Last Message Sent At", as: :date, format: "yyyy-LL-dd HH:mm" do
      record.conversations.joins(:messages).order("messages.created_at DESC").limit(1).pluck("messages.created_at").first
    rescue
      nil
    end
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
