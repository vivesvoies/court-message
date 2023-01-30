# Included for every record that takes part in a conversation
module Conversationalist
  extend ActiveSupport::Concern

  def identifier
    name.presence || (respond_to?(:phone) ? phone.presence : nil) || email
  end

  def to_s = identifier
end
