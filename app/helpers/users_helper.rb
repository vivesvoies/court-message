module UsersHelper
  # Options for the invitation form's membership-role selector.
  def membership_roles_collection
    Membership.roles.keys.map { |role| [ I18n.t("memberships.roles.#{role}"), role ] }
  end
end
