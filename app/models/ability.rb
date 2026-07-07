# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user.present?
    belongs_to_team = { team: { id: user.team_ids } }

    # Rules for all users -> be part of team
    can :read, User, memberships: belongs_to_team
    can :update, User, id: user.id
    can [ :read, :menu ], Team, belongs_to_team
    can [ :create, :read ], Conversation, belongs_to_team
    can :create, Message, belongs_to_team
    can :manage, Contact, belongs_to_team
    can :manage, Template, user_id: user.id

    # Rules for team admins -> scoped to the teams where the membership is admin.
    # Team administration is now per-team (see #130): a user may be admin of one
    # team and a plain member of another.
    admin_team_ids = user.admin_team_ids
    if admin_team_ids.any?
      admin_of_team = { team: { id: admin_team_ids } }
      # Create teams, add members, manage members -> only for admin teams
      can [ :create, :update, :destroy ], User, memberships: admin_of_team
      can [ :read, :create, :update ], Team, admin_of_team
      can :manage, Membership, admin_of_team
      cannot :destroy, User, id: user.id
    end
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
