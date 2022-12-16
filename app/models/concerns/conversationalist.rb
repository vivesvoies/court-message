# Included for every record that takes part in a conversation
module Conversationalist
  extend ActiveSupport::Concern

  def name_or_phone
    name.presence || phone
  end
end
