class Avo::Resources::PhoneLine < Avo::BaseResource
  self.includes = [ :sms_gateway ]

  def fields
    field :id, as: :id, link_to_record: true
    field :phone, as: :text
    field :provider, as: :select, options: PhoneLine::PROVIDERS.index_by(&:humanize)
    field :default, as: :boolean
    field :sms_gateway, as: :belongs_to
    field :teams, as: :has_many, hide_on: [ :new, :edit ]
  end
end
