# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    belongs_to_team = { team: { id: user.team_ids } }

    # Rules for all users -> be part of team
    return unless user.present?
    can :read, Team, belongs_to_team
    can :read, Conversation, belongs_to_team
    can :create, Message, belongs_to_team
    can :manage, Contact, belongs_to_team
    
    # Rules for team admins -> create teams, add members, manage members
    return unless user.at_least?(:team_admin)
    can :manage, Team, belongs_to_team
    can :manage, Membership, belongs_to_team

    return unless user.at_least?(:site_admin)
    can [:read, :update], User

    return unless user.at_least?(:super_admin)
    can :manage, :all
  end

end
