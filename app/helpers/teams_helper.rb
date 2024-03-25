module TeamsHelper
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
