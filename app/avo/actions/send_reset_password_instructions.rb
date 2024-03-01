class Avo::Actions::SendResetPasswordInstructions < Avo::BaseAction
  self.name = "Envoyer le mail pour réinitialiser le mot de passe"

  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)

    query.each do |record|
      User.find(record.id).send_reset_password_instructions
      succeed "Parfait le mail a été envoyé à #{record.email}"
    end
  end
end
