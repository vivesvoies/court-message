module TeamsHelper
  def menu_for(label, icon:, destination:, frame: :conversation_detail)
    active = current_page?(destination)
    render partial: "menu_item", locals: { label:, icon:, active:, destination:, frame: }
  end
end


