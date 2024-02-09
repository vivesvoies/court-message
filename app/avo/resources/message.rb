class Avo::Resources::Message < Avo::BaseResource
  self.includes = []
  # TODO: Did we keep the Message resource from the sidebar?

  def fields
    field :id, as: :id
    # TODO: truncate the message if more than 10-15 character
    field :content, as: :text
    # TODO: Check whether the Status field in the documentation is more suitable than badge
    field :status,
      as: :badge,
      options: {
        info: :submitted, # blue
        success: [ :delivered, :inbound ], # green
        warning: :undeliverable, # yellow
        danger: :rejected, # red
        neutral: :unsent # gray
      },
      sortable: true
    field :conversation, as: :belongs_to
    field :sender, as: :belongs_to, polymorphic_as: :sender, types: [ ::User ]
    field :created_at,
      as: :date,
      format: "yyyy-LL-dd"
    field :updated_at,
      as: :date,
      format: "yyyy-LL-dd"
    if view.show?
      field :provider_info, as: :text
      field :conversation_id, as: :number
      field :sender_type, as: :text
      field :sender_id, as: :number
      field :outbound_uuid, as: :text
    end
  end
end
