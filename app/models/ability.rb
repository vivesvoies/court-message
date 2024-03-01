# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user.present?
    belongs_to_team = { team: { id: user.team_ids } }

    # Rules for all users -> be part of team
    can :read, User, memberships: belongs_to_team
    can :update, User, id: user.id
    can :read, Team, belongs_to_team
    can :read, Conversation, belongs_to_team
    can :create, Message, belongs_to_team
    can :manage, Contact, belongs_to_team
    return unless user.at_least?(:team_admin)

    # Rules for team admins -> create teams, add members, manage members
    can [ :create, :update, :destroy ], User, memberships: belongs_to_team
    can [ :read, :create, :update ], Team, belongs_to_team
    can :manage, Membership, belongs_to_team
    cannot :destroy, User, id: user.id
    return unless user.at_least?(:site_admin)

    # Rules for site admins -> manage every user and team
    can :manage, Team
    can :manage, User
    can :manage, Contact
    can :manage, Membership
    cannot :destroy, User, id: user.id
    return unless user.at_least?(:super_admin)

    can :manage, :all
    cannot :destroy, User, id: user.id
  end
end
