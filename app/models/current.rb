# Singleton that holds attributes for the current request.
class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :phone_number
  attribute :team
end
