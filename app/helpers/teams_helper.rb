module TeamsHelper
  def menu_for(label, icon:, destination:, frame: :primary)
    active = current_page?(destination)
    render partial: "menu_item", locals: { label:, icon:, active:, destination:, frame: }
  end

  def menu_link_destination(team)
    if params[:controller] == "conversations"
      menu_team_path(team)
    else
      team_conversations_path(team)
    end
  end
end
