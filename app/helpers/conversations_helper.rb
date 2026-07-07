module ConversationsHelper
  def current_conversation?(conversation)
    params[:selected] == conversation.id.to_s or @conversation == conversation
  end

  def last_message_extract_for(conversation)
    content = conversation.last_message&.content || ""
    (content.length > 113) ? "#{content[0...110]}..." : content
  end

  def unread_badge_for(conversation)
    count = conversation.unread_count
    return if count.zero?

    tag.span((count > 9) ? "9+" : count.to_s, class: "Conversation__unread-count")
  end

  def last_message_class_for(conversation)
    direction = conversation.last_message&.direction
    direction ? "Conversation__sub--#{direction}" : "Conversation__sub--empty"
  end

  def link_to_or_create_conversation(contact, team)
    if contact.conversation.present?
      link_to contact.name, team_conversation_path(team, contact.conversation.id), class: "ContactSearchResult__action", data: { turbo_frame: :primary, turbo_action: :advance }
    else
      button_to contact.name, team_conversations_path(@team, contact: contact.id),
          method: :post,
          data: { turbo_frame: :primary },
          class: "ContactSearchResult__action"
    end
  end
end
