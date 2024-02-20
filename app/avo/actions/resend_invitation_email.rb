class Avo::Actions::ResendInvitationEmail < Avo::BaseAction
  self.name = "Renvoyer une invitation"

  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)

    query.each do |record|
      # TODO: Should resend an invitation email to join the team
    end

    succeed "Parfait c'est envoyé!"
  end
end
