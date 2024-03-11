class Avo::Resources::User < Avo::BaseResource
  self.includes = []

  def fields
    # Field template for user in the main page
    field :id, as: :id, sortable: true, link_to_record: true
    field :name, as: :text, sortable: true
    field :email, as: :text, sortable: true
    field "is admin", as: :boolean do
      record.role != "user"
    end
    field :role, as: :select, enum: ::User.roles, display_with_value: true, sortable: true
    field :created_at,
      as: :date,
      format: "yyyy-LL-dd",
      sortable: true
    field "is confirmed", as: :boolean do
      record.confirmed_at.present?
    rescue
      false
    end
    # Field template only available in page show
    if view.show?
      field :confirmed_at,
        as: :date,
        format: "yyyy-LL-dd"
      field :confirmation_sent_at,
        as: :date,
        format: "yyyy-LL-dd"
      field :updated_at,
        as: :date,
        format: "yyyy-LL-dd"
      field :remember_created_at,
        as: :date,
        format: "yyyy-LL-dd"
      field :reset_password_sent_at,
        as: :date,
        format: "yyyy-LL-dd"
      field :confirmation_token, as: :text
      field :reset_password_token, as: :text
      field :unconfirmed_email, as: :text, show_on: :index
      field :messages, as: :has_many, visible: -> { resource.record.messages.any? }
      field :conversations, as: :has_and_belongs_to_many, visible: -> { resource.record.conversations.any? }
    end
      # TODO: Password modification is possible. Could be better to just resend an email for reset password?
      field :password, as: :password
      field :teams, as: :has_many, through: :memberships
  end

  # Actions that can be performed on user
  def actions
    action Avo::Actions::ResendInvitationEmail
    action Avo::Actions::SendConfirmationInstructions
    action Avo::Actions::SendResetPasswordInstructions
  end
end
