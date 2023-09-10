# == Schema Information
#
# Table name: conversations
#
#  id         :bigint           not null, primary key
#  read       :boolean          default(TRUE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  contact_id :bigint           not null
#
# Indexes
#
#  index_conversations_on_contact_id  (contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (contact_id => contacts.id)
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
end
