# Singleton that holds attributes for the current request.
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :phone_number
end
