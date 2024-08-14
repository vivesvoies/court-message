# == Schema Information
#
# Table name: conversations
#
#  id              :bigint           not null, primary key
#  read            :boolean          default(TRUE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  contact_id      :bigint           not null
#  last_message_id :bigint
#
# Indexes
#
#  index_conversations_on_contact_id       (contact_id)
#  index_conversations_on_last_message_id  (last_message_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (last_message_id => messages.id)
#
require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  def test_title_shows_name_if_present
    @contact = create(:contact)
    @conversation = @contact.create_conversation

    assert_equal(@conversation.title, @contact.name)
  end

  def test_title_shows_formatted_phone_when_no_name
    @contact = create(:contact, name: "")
    @conversation = @contact.create_conversation

    assert_equal(@contact.to_s, @conversation.title)
  end

  def test_messages_ordering
    @conversation = create(:conversation) do |conversation|
      create_list(:inbound_message, 10, conversation:)
    end

    m = @conversation.messages.third
    m.update(created_at: Date.yesterday)
    assert_equal(m, @conversation.messages.first)
  end

  def test_updates_upon_new_message
    @conversation = create(:conversation)
    assert_changes "@conversation.updated_at" do
      @conversation.messages << create(:inbound_message)
    end
  end

  def test_team_scope
    teams = create_list(:team, 2) do |team|
      create_list(:conversation, 3, team:)
    end
    team_1 = teams[0]
    team_1_convos = team_1.conversations
    assert_equal(team_1_convos.sort, Conversation.for_team(team_1).sort)
  end

  def test_preloading_last_message_in_team_scope
    team = create(:team) do |team|
      create_list(:conversation, 3, team:)
    end
    conversations = team.conversations
    conversations.each do |convo|
      convo.messages << create(:inbound_message)
    end

    preloaded = Conversation.for_team(team)

    assert_equal(1, count_queries { preloaded.map(&:last_message) })
  end

  def test_team_scope_ordering
    team = create(:team) do |team|
      create_list(:conversation, 3, team:)
    end
    conversations = team.conversations
    conversations.each do |convo|
      convo.messages << create(:inbound_message)
    end

    # Order by last message, then by conversation updated_at
    preloaded = Conversation.for_team(team)

    assert_equal(preloaded, conversations.sort_by(&:timestamp).reverse)
    assert_equal(preloaded.first, conversations.last)

    # When a message is added, the conversation jumps to the top
    conversations.first.messages << create(:outbound_message)
    preloaded = Conversation.for_team(team)

    assert_equal(preloaded, conversations.sort_by(&:timestamp).reverse)
    assert_equal(preloaded.first, conversations.first)

    # When a conversastion is updated, it does not jump to the top
    conversations.second.touch
    preloaded = Conversation.for_team(team)
    assert_not_equal(preloaded.first, conversations.second)
  end

  def test_complex_team_scope_ordering
    # ensure that messages.updated_at and conversations.updated_at are both coalesced

    team = create(:team)
    oldest = create(:conversation, team:, updated_at: 1.day.ago)
    middle = create(:conversation, team:, updated_at: 1.hour.ago)
    newest = create(:conversation, team:, updated_at: 1.minute.ago)

    preloaded = Conversation.for_team(team).pluck(:id)
    assert_equal([ newest.id, middle.id, oldest.id ], preloaded)

    oldest.messages << create(:inbound_message)
    preloaded = Conversation.for_team(team).pluck(:id)
    assert_equal([ oldest.id, newest.id, middle.id ], preloaded)
  end

  def test_user_scope
    team = create(:team)
    user = create(:user)
    other_user = create(:user)

    team_conversations = create_list(:conversation, 3, contact: create(:contact, team: team))

    user_conversations = team_conversations[0..1]
    user.conversations << user_conversations

    result = Conversation.for_user(user, team)
    assert_equal(user_conversations.sort, result.sort)
    assert_not_includes(result, team_conversations[2])
  end

  def test_user_scope_ordering
    team = create(:team)
    user = create(:user)

    convos = create_list(:conversation, 3, contact: create(:contact, team: team))
    user.conversations << convos

    convos.each { |convo| convo.messages << create(:inbound_message) }

    preloaded = Conversation.for_user(user, team)
    assert_equal(preloaded, convos.sort_by(&:timestamp).reverse)
    assert_equal(preloaded.first, convos.last)

    convos.first.messages << create(:outbound_message)
    preloaded = Conversation.for_user(user, team)
    assert_equal(preloaded, convos.sort_by(&:timestamp).reverse)
    assert_equal(preloaded.first, convos.first)

    convos.second.touch
    preloaded = Conversation.for_user(user, team)
    assert_not_equal(preloaded.first, convos.second)
  end

  def test_complex_user_scope_ordering
    team = create(:team)
    user = create(:user)

    oldest = create(:conversation, contact: create(:contact, team: team), updated_at: 1.day.ago)
    middle = create(:conversation, contact: create(:contact, team: team), updated_at: 1.hour.ago)
    newest = create(:conversation, contact: create(:contact, team: team), updated_at: 1.minute.ago)

    user.conversations << [ oldest, middle, newest ]

    preloaded = Conversation.for_user(user, team).pluck(:id)
    assert_equal([ newest.id, middle.id, oldest.id ], preloaded)

    oldest.messages << create(:inbound_message)
    preloaded = Conversation.for_user(user, team).pluck(:id)
    assert_equal([ oldest.id, newest.id, middle.id ], preloaded)
  end

  def test_user_scope_with_multiple_teams
    team_1 = create(:team)
    team_2 = create(:team)
    user = create(:user)

    team_1_conversations = create_list(:conversation, 2, contact: create(:contact, team: team_1))
    team_2_conversations = create_list(:conversation, 2, contact: create(:contact, team: team_2))

    user.conversations << team_1_conversations
    user.conversations << team_2_conversations

    result = Conversation.for_user(user, team_1)
    assert_equal(team_1_conversations.sort, result.sort)
    assert_not_includes(result, team_2_conversations[0])
    assert_not_includes(result, team_2_conversations[1])
  end

  def test_broadcast_to_user_conversations_on_new_message
    team = create(:team)
    user = create(:user)
    other_user = create(:user)

    conversation_1 = create(:conversation, contact: create(:contact, team: team))
    conversation_2 = create(:conversation, contact: create(:contact, team: team))

    user.conversations << conversation_1
    other_user.conversations << conversation_2

    inbound_message = create(:inbound_message, conversation: conversation_1)

    # Add a message to conversation_1 and check broadcast for user
    assert_turbo_stream_broadcasts "user_conversations_list_#{user.id}" do
      conversation_1.messages << inbound_message
    end

    # Verify that conversation_2 does not broadcast to user
    assert_no_turbo_stream_broadcasts("user_conversations_list_#{other_user.id}") do
      conversation_1.messages << create(:inbound_message)
    end
  end

  def test_broadcast_to_multiple_users_with_shared_conversation
    team = create(:team)
    user = create(:user)
    other_user = create(:user)

    conversation = create(:conversation, contact: create(:contact, team: team))
    user.conversations << conversation
    other_user.conversations << conversation

    assert_turbo_stream_broadcasts "user_conversations_list_#{user.id}" do
      assert_turbo_stream_broadcasts "user_conversations_list_#{other_user.id}" do
        conversation.messages << create(:inbound_message)
      end
    end
  end

  def test_preloading_query
    c = create(:conversation) do |conversation|
      create_list(:inbound_message, 10, conversation:)
      conversation.agents << create(:user)
    end

    preloaded = Conversation.find_preloaded(c.id)

    assert_equal(0, count_queries { preloaded.messages.first.content })
    assert_equal(0, count_queries { preloaded.agents.first.identifier })
    assert_equal(0, count_queries { preloaded.contact.name })
  end

  def test_default_as_read
    @conversation = create(:conversation)
    assert(@conversation.read?)
  end

  def test_mark_as_read
    @conversation = create(:conversation, read: false)
    assert_changes "@conversation.unread?" do
      @conversation.mark_as_read!
    end
  end

  def test_mark_as_unread
    @conversation = create(:conversation, read: true)
    assert_changes "@conversation.unread?" do
      @conversation.mark_as_unread!
    end
  end

  def test_read
    @conversation = create(:conversation, read: true)
    assert(@conversation.read?)
  end

  def test_unread
    @conversation = create(:conversation, read: false)
    assert(@conversation.unread?)
  end

  def test_status_string
    @conversation = create(:conversation, read: true)
    assert_equal(@conversation.status, "read")
    @conversation.mark_as_unread!
    assert_equal(@conversation.status, "unread")
  end

  def test_last_message
    @conversation = create(:conversation)
    @conversation.messages << create(:inbound_message)
    last = create(:outbound_message)
    @conversation.messages << last
    assert_equal(last, @conversation.last_message)
  end

  def test_timestamp_is_never_nil
    @conversation = create(:conversation)
    @conversation.messages << create(:inbound_message)

    assert_equal(@conversation.last_message.updated_at, @conversation.timestamp)

    @new_conversation = create(:conversation)
    assert_equal(@new_conversation.updated_at, @new_conversation.timestamp)
  end
end
