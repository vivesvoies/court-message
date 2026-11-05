class Avo::Resources::PhoneLine < Avo::BaseResource
  self.includes = [ :sms_gateway, :fallback_phone_line ]

  def fields
    field :id, as: :id, link_to_record: true
    field :phone, as: :text
    field :provider, as: :select, options: PhoneLine::PROVIDERS.index_by(&:humanize)
    field :active, as: :boolean, name: "Active"
    field :default, as: :boolean
    field :sms_gateway, as: :belongs_to
    field :fallback_phone_line, as: :belongs_to, name: "Ligne de secours"
    field :fallback_after_minutes, as: :number, name: "Bascule auto après (minutes)",
      help: "Vide = pas de bascule automatique. Les messages en attente depuis plus longtemps partent par la ligne de secours."
    field :modem_ok, as: :boolean, name: "Modem OK", readonly: true, hide_on: [ :new, :edit ]
    field :last_modem_check_at, as: :date_time, name: "Dernier check modem", readonly: true, hide_on: [ :new, :edit ]
    if view.show?
      field :modem_details, as: :code, language: "javascript", readonly: true, format_using: -> { value&.to_json }
    end
    field :teams, as: :has_many, hide_on: [ :new, :edit ]
  end

  def actions
    action Avo::Actions::FailOverPhoneLine
  end
end
