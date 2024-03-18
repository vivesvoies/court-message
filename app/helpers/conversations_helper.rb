module ConversationsHelper
  def last_message_extract_for(conversation)
    content = conversation.messages.order(created_at: :asc)&.last&.content || ""
    (content.length > 113) ? "#{content[0...110]}..." : content
  end

  def last_message_class_for(conversation)
    direction = conversation.messages.last&.direction
    direction ? "Conversation__sub--#{direction}" : "Conversation__sub--empty"
  end

  def last_message_timestamp(conversation)
    time_stamp_for conversation.messages.where(status: [ :delivered, :inbound ]).maximum(:created_at)
  end
end
