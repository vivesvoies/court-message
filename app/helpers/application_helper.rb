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

  def tab_for(label, icon:, destination:, frame: nil, mobile: false, active: false, **attr)
    link_class = "TabBarButton cm-btn cm-btn--caption cm-icon-#{icon}"
    link_class += " cm-small-only" if mobile == :only
    link_class += " TabBarButton--active" if active
    link_to t(".#{label}"),
      destination,
      id: "tab-btn-#{label}",
      data: {
        action: "tab-bar#selectTab",
        turbo_frame: frame,
        tab_bar_label_param: label,
        tab_bar_target: "tab",
        turbo_action: :advance
      },
      class: link_class
  end

  def should_load_conversations?
    @team.present? && !content_for?(:navigation) && current_frame.nil?
  end
end
