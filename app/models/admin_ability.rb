class AdminAbility
    include CanCan::Ability

    def initialize(user)
      return unless user && user.at_least?(:team_admin)

      can :access, :rails_admin   # grant access to rails_admin
      can :read, :dashboard       # grant access to the dashboard
      can :read, :all

      return unless user.at_least?(:site_admin)

      can :manage, :all
    end
end
