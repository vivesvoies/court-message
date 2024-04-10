module ConversationsHelper
  def last_message_extract_for(conversation)
    content = conversation.last_message&.content || ""
    (content.length > 113) ? "#{content[0...110]}..." : content
  end

  def last_message_class_for(conversation)
    direction = conversation.last_message&.direction
    direction ? "Conversation__sub--#{direction}" : "Conversation__sub--empty"
  end

  def link_to_or_create_conversation(contact, team)
    if contact.conversation.present?
      link_to contact.name, team_conversation_path(team, contact.conversation.id), class: "ContactSearchResult__action", data: { turbo_frame: :primary }
    else
      button_to contact.name, team_conversations_path(@team, contact: contact.id),
          method: :post,
          data: { turbo_frame: :primary },
          class: "ContactSearchResult__action"
    end
  end
end
