# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

Rails.logger.info("Seed the DB on environment: #{Rails.env}")
Rails.logger.info("___________________________")
raise "You are in production or staging environment! Won't modify DB, bye :)" unless Rails.env.local?

# Clean test DB

User.destroy_all
Contact.destroy_all
Team.destroy_all
Conversation.destroy_all
Membership.destroy_all
Message.destroy_all

# Users and Teams

users = [
  {
    id: 1,
    name: "Admin Super",
    email: "super@court-message.fr",
    password: "fakePassw0rd",
    confirmed_at: DateTime.now.utc,
    role: "super_admin"
  },
  {
    id: 2,
    name: "Admin Site",
    email: "site@court-message.fr",
    password: "fakePassw0rd",
    confirmed_at: DateTime.now.utc,
    role: "site_admin"
  },
  {
    id: 3,
    name: "Admin Team",
    email: "team@court-message.fr",
    password: "fakePassw0rd",
    confirmed_at: DateTime.now.utc,
    role: "team_admin"
  },
  {
    id: 4,
    name: "Marthe Bellemare",
    email: "marthe@court-message.fr",
    password: "fakePassw0rd",
    confirmed_at: DateTime.new(2021, 1, 1),
    role: "user"
  },
  {
    id: 5,
    name: "Yoan Jacquet",
    email: "yoan@court-message.fr",
    password: "fakePassw0rd",
    confirmed_at: DateTime.new(2022, 12, 30),
    role: "user"
  },
  {
    id: 6,
    name: "Lionel Léotard",
    email: "lionel@court-message.fr",
    password: "fakePassw0rd",
    confirmed_at: DateTime.now.utc,
    role: "user"
  }
]

Rails.logger.info("Creating users:")
users.each do |user|
  Rails.logger.info("Creating user: #{user[:name]}")
  User.create!(user)
end

teams = [
  {
    id: 1,
    name: "AdminTeam",
    address: "123 Fake Street, AdminCity, AdminCountry"
  },
  {
    id: 2,
    name: "UserTeam",
    address: "456 Fun Avenue, UserCity, UserCountry"
  }
]

Rails.logger.info("Creating teams:")
teams.each do |team|
  team = Team.create!(team)
  Rails.logger.info("Creating team: #{team[:name]}")
end

memberships = [
  {
    team_id: 1,
    user_id: 1
  },
  {
    team_id: 1,
    user_id: 2
  },
  {
    team_id: 1,
    user_id: 3
  },
  {
    team_id: 2,
    user_id: 3
  },
  {
    team_id: 2,
    user_id: 4
  },
  {
    team_id: 2,
    user_id: 5
  },
  {
    team_id: 2,
    user_id: 6
  }
]

Rails.logger.info("Creating membership:")
memberships.each do |membership|
  Membership.create(team: Team.find(membership[:team_id]), user: User.find(membership[:user_id]))
end

# Contacts and Conversation

contacts = [
  {
    id: 1,
    name: "Alice Legendre",
    email: "alice@mail.com",
    phone: "+33 6 10 34 37 99",
    notes: "Besoin d’aide dans recherche de logement\nPenser à l’ajouter à la liste de diffusion “Logement de 2023”",
    notes_updated_at: DateTime.now.utc,
    notes_updated_by: User.find(4),
    team_id: 2
  },
  {
    id: 2,
    name: "Zarha Alami",
    email: "zahra@mail.com",
    phone: "+33 6 10 56 76 90",
    team_id: 2
  },
  {
    id: 3,
    name: "Joyce Selegenda",
    email: "joyce@mail.com",
    phone: "+33 7 35 47 82 09",
    team_id: 2
  },
  {
    id: 4,
    name: "Tarek Amedine",
    email: "tarek@mail.com",
    phone: "+33 6 98 37 46 59 ",
    notes: "A contacter",
    notes_updated_at: DateTime.now.utc,
    notes_updated_by: User.find(5),
    team_id: 2
  }
]

Rails.logger.info("Creating contacts:")
contacts.each do |contact|
  Contact.create!(contact)
  Rails.logger.info("Creating contact: #{contact[:name]}")
end


conversations = [
  {
    id: 1,
    read: false,
    created_at: DateTime.now.utc,
    contact_id: 1
  },
  {
    id: 2,
    read: false,
    created_at: DateTime.now.utc,
    contact_id: 2
  },
  {
    id: 3,
    read: false,
    created_at: DateTime.now.utc,
    contact_id: 3
  }
]

Rails.logger.info("Creating conversations:")
conversations.each do |conversation|
  Conversation.create!(conversation)
end

messages = [
  {
    id: 1,
    content: "Je suis un message de test status: inbound",
    status: "inbound",
    created_at: DateTime.now.utc.years_ago(1),
    conversation_id: 1,
    sender_type: "User",
    sender_id: 4
  },
  {
    id: 2,
    content: "Je suis un message de test status: unsent",
    status: "unsent",
    created_at: DateTime.now.utc.months_ago(1),
    conversation_id: 1,
    sender_type: "User",
    sender_id: 4
  },
  {
    id: 3,
    content: "Je suis un message de test status: submitted",
    status: "submitted",
    created_at: DateTime.now.utc.weeks_ago(1),
    conversation_id: 1,
    sender_type: "User",
    sender_id: 4
  },
  {
    id: 4,
    content: "Je suis un message de test status: delivered",
    status: "delivered",
    created_at: DateTime.now.utc.days_ago(2),
    conversation_id: 1,
    sender_type: "User",
    sender_id: 4
  },
  {
    id: 5,
    content: "Je suis un message de test status: rejected",
    status: "rejected",
    created_at: DateTime.now.utc.days_ago(1),
    conversation_id: 1,
    sender_type: "User",
    sender_id: 4
  },
  {
    id: 6,
    content: "Je suis un message de test status: undeliverable",
    status: "undeliverable",
    created_at: DateTime.now.utc,
    conversation_id: 1,
    sender_type: "User",
    sender_id: 4
  },
  {
    id: 7,
    content: "Je suis un message de test status: inbound",
    status: "inbound",
    created_at: DateTime.now.utc.years_ago(1),
    conversation_id: 3,
    sender_type: "User",
    sender_id: 6
  },
  {
    id: 8,
    content: "Je suis un message de test status: delivered",
    status: "delivered",
    created_at: DateTime.now.utc.years_ago(1),
    conversation_id: 3,
    sender_type: "User",
    sender_id: 4
  }
]

Rails.logger.info("Creating messages:")
messages.each do |message|
  new_message = Message.new(message)
  new_message.save
end
