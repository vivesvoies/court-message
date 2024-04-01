class Avo::Actions::ResendInvitationEmail < Avo::BaseAction
  self.name = "Renvoyer une invitation"

  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)

    query.each do |record|
      record.invitation_sent_at = DateTime.now.utc
      record.invite!
      succeed "Parfait c'est envoyé à #{record.email}"
    end
  end
end
