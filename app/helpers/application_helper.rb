module ApplicationHelper
  def time_stamp_for(time)
    return "" if time.nil?

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
      data: {
        action: "tab-bar#selectTab",
        turbo_frame: frame,
        tab_bar_label_param: label,
        tab_bar_target: "tab"
      },
      class: link_class
  end
end
