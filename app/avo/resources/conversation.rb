class Avo::Resources::Conversation < Avo::BaseResource
  self.includes = []

  def fields
    field :id, as: :id
    field :contact_id, as: :number, hide_on: [ :index ]
    field :read, as: :boolean
    field :contact, as: :belongs_to
    field :team, as: :belongs_to
    field :messages, as: :has_many, visible: -> { resource.record.messages.any? }
    if view.index?
      field "Number of Messages", as: :number do
        record.messages.count
      rescue
        false
      end

      field "Last Message Created At", as: :date, format: "yyyy-LL-dd HH:mm" do
        record.last_message&.created_at
      rescue
        false
      end

      field "Number of Agents", as: :number do
        record.agents.count
      rescue
        0
      end
    end
    field :agents, as: :has_and_belongs_to_many, visible: -> { resource.record.agents.any? }
  end
end
