class Avo::Resources::SmsGateway < Avo::BaseResource
  self.includes = []

  def fields
    field :id, as: :id, link_to_record: true
    field :name, as: :text
    field :last_seen_at, as: :date_time, readonly: true
    field :created_at, as: :date, format: "yyyy-LL-dd", hide_on: [ :new, :edit ]
    field :phone_lines, as: :has_many
  end
end
