module TeamsHelper
  def tab_for(label, icon:, destination:, frame: nil, mobile: false, active: false, **attr)
    link_class = "TabBarButton cm-btn cm-btn--caption cm-icon-#{icon}"
    link_class += " cm-small-only" if mobile == :only
    link_class += " TabBarButton--active" if active
    link_to t(".#{label}"),
      destination,
      id: "tab-btn-#{label}",
      data: {
        action: "navigation#selectTab",
        turbo_frame: frame,
        navigation_label_param: label,
        navigation_target: "tab",
        turbo_action: :advance
      },
      class: link_class
  end

  def menu_for(label, icon:, destination:, frame: :primary)
    active = current_page?(destination)
    render partial: "menu_item", locals: { label:, icon:, active:, destination:, frame: }
  end

  def menu_link_destination(team)
    params[:controller] == "conversations" ? menu_team_path(team) : team_conversations_path(team)
  end

  def link_to_menu(team)
    action = params[:controller] == "teams" ? "viewer#menuClose" : "viewer#menuOpen"
    link_to menu_link_destination(team), class: "ConversationSidebar__menuButton", data: { action: } do
      yield
    end
  end
end
