class Avo::Actions::SendConfirmationInstructions < Avo::BaseAction
  self.name = "Renvoyer le mail de confirmation"

  def handle(**args)
    query, fields, current_user, resource = args.values_at(:query, :fields, :current_user, :resource)

    query.each do |record|
      record.confirmation_sent_at = DateTime.now.utc
      resp = User.find(record.id).send_confirmation_instructions
      succeed "Parfait le mail a été envoyé à #{record.email}"
    end
  end
end
