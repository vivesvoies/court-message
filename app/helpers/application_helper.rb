module ApplicationHelper
  def time_stamp_for time
    case
    when time.today?
      time.strftime("%H:%M")
    when time.past? && (Time.zone.now - time) < 7.days
      I18n.l(time, format: "%A")
    else
      I18n.l(time.to_date, format: :default)
    end
  end
end
