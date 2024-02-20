class Avo::Actions::ResendConfirmationEmail < Avo::BaseAction
  self.name = "Renvoyer le mail de confirmation"

  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)

    query.each do |record|
      record.confirmation_sent_at = DateTime.now.utc

      # TODO: Should resend a confirmation email to join the team
    end

    succeed "Parfait c'est envoyé!"
  end
end
