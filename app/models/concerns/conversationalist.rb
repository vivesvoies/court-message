# Included for every record that takes part in a conversation
module Conversationalist
  extend ActiveSupport::Concern

  def identifier
    case
    when name.present?
      name
    when respond_to?(:phone) && phone.present?
      formatted_phone
    when email.present?
      email
    else
      "#<#{self.class} id=#{self.id}>"
    end
  end

  def to_s = identifier
end
