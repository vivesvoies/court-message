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
    # When the layout is not loaded via turbo frame request, yet no content is provided for the navigation
    # Typically happens when visiting a page other than the index.
    @team.present? && !content_for?(:navigation) && !turbo_frame_request?
  end

  def lazy_loaded_conversations_path
    conversation = @conversation || @contact&.conversation
    team_conversations_path(@team, selected: conversation&.id)
  end

  def content_and_flash_for(frame)
    content_for(frame) + content_for(:flash_stream) if content_for? frame
  end

  def umami_tracking_code
    raw %(<script defer src="https://cloud.umami.is/script.js" data-website-id="89c6127c-ee17-47c2-9112-eda9494055f5"></script>)
  end
end
