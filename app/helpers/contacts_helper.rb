module ContactsHelper
  def info_tag(model, key:, missing:)
    klass = "#{model.class.name}__#{key}"
    value = model.send(key)
    if value.blank?
      klass += " #{klass}--missing"
    end
    content = value.presence || missing

    tag.div content, class: klass
  end
end
