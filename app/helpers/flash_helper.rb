module FlashHelper
  def flash_id(type, message) = [ type, message[0, 50] ].join("-").parameterize

  def flash_cm_class(flash_type)
    type = flash_type.to_s.parameterize
    case type
    when "notice"
      "cm-alert--#{type} cm-alert--info"
    when "alert"
      "cm-alert--#{type} cm-alert--warn"
    else
      "cm-alert--#{type}"
    end
  end

  def flash_icon(type)
    case type
    when :warn, "warn"
      "warning"
    when :disabled, "disabled"
      "cross"
    when :success, "success"
      "checkmark"
    when :info, "info"
      "info"
    when :delete, "delete"
      "bin"
    else
      "info"
    end
  end
end
