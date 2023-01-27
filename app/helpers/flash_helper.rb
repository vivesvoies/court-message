module FlashHelper
  def flash_id(type, message) = [type, message[0, 10]].join("-").parameterize

  def flash_dsfr_class(type)
    case type
    when :notice, "notice"
      "fr-alert--info"
    when :alert, "alert"
      "fr-alert--error"
    else
      "fr-alert--#{type.to_s.parameterize}"
    end
  end
end
