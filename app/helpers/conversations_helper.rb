module ConversationsHelper
  def last_message_extract_for(conversation)
    content = conversation.last_message&.content || ""
    (content.length > 113) ? "#{content[0...110]}..." : content
  end

  def last_message_class_for(conversation)
    direction = conversation.last_message&.direction
    direction ? "Conversation__sub--#{direction}" : "Conversation__sub--empty"
  end
end
