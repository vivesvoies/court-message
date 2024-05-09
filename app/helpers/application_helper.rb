module ApplicationHelper
  def time_stamp_for(time)
    if time.today?
      time.strftime("%H:%M")
    elsif time.yesterday?
      I18n.l(time, format: :yesterday)
    elsif time.past? && (Time.zone.now - time) < 7.days
      I18n.l(time, format: "%A")
    else
      I18n.l(time.to_date, format: :default)
    end
  end

  def should_load_conversations?
    @team.present? && !content_for?(:navigation) && current_frame.nil?
  end

  def lazy_loaded_conversations_path
    conversation = @conversation || @contact&.conversation
    team_conversations_path(@team, selected: conversation&.id)
  end

  def content_and_flash_for(frame)
    content_for(frame) + content_for(:flash_stream) if content_for? frame
  end
end
