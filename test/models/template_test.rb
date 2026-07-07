# == Schema Information
#
# Table name: templates
#
#  id         :bigint           not null, primary key
#  content    :text
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint
#  user_id    :bigint
#
# Indexes
#
#  index_templates_on_team_id  (team_id)
#  index_templates_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#

require "test_helper"

class TemplateTest < ActiveSupport::TestCase
  test "should not be valid if content is nil" do
    user = create(:user)
    template = build(:template, user: user, content: nil)
    assert_not template.valid?
  end

  test "should not be valid if empty content" do
    user = create(:user)
    template = build(:template, user: user, content: "")
    assert_not template.valid?
  end

  test "should be valid with content" do
    template = build(:template)
    assert template.valid?
    assert template.save
  end

  test "should be valid with valid attributes" do
    user = create(:user)
    template = create(:template, user:)
    assert template.valid?
  end

  test "should be valid without a title" do
    template = create(:template, title: "")
    assert template.valid?
  end

  test "should belong to a user" do
    association = Template.reflect_on_association(:user)
    assert_equal :belongs_to, association.macro
  end

  test "personal scope returns templates without a team" do
    personal = create(:template)
    create(:template, :shared)

    assert_includes Template.personal, personal
    assert_equal Template.personal.count, Template.personal.where(team_id: nil).count
  end

  test "shared scope returns templates with a team" do
    shared = create(:template, :shared)
    create(:template)

    assert_includes Template.shared, shared
    assert_equal Template.shared.count, Template.shared.where.not(team_id: nil).count
  end

  test "shared? reflects the presence of a team" do
    assert_not create(:template).shared?
    assert create(:template, :shared).shared?
  end

  test "a team template does not require a user" do
    team = create(:team)
    template = build(:template, user: nil, team:)
    assert template.valid?
  end

  test "a personal template requires a user" do
    template = build(:template, user: nil, team: nil)
    assert_not template.valid?
  end

  test "title round-trips through create and update" do
    template = create(:template, title: "Bienvenue")
    assert_equal "Bienvenue", template.reload.title

    template.update(title: "Bienvenue à tous")
    assert_equal "Bienvenue à tous", template.reload.title
  end

  test "destroying a user destroys their personal templates" do
    user = create(:user)
    personal = create(:template, user:)

    user.destroy

    assert_not Template.exists?(personal.id)
  end

  test "destroying a user keeps their team templates but releases ownership" do
    user = create(:user)
    team = user.teams.first
    shared = create(:template, :shared, user:, team:)

    user.destroy

    shared.reload
    assert_nil shared.user_id
    assert_equal team.id, shared.team_id
    assert Template.exists?(shared.id)
  end
end
