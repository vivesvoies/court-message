class Avo::Resources::Conversation < Avo::BaseResource
  self.includes = []

  def fields
    field :id, as: :id
    field :contact_id, as: :number, hide_on: [ :index ]
    field :read, as: :boolean
    field :contact, as: :belongs_to
    field :team, as: :belongs_to
    field :messages, as: :has_many, visible: -> { resource.record.messages.any? }
    field :agents, as: :has_and_belongs_to_many, visible: -> { resource.record.agents.any? }
  end
end
