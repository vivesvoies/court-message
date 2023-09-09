module UsersHelper
  def roles_collection
    Current.user.bestowable_roles.map { |role| [I18n.t("roles." + role), role] }
  end
end
