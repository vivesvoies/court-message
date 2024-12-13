# == Schema Information
#
# Table name: templates
#
#  id         :bigint           not null, primary key
#  content    :text
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_templates_on_user_id  (user_id)
#
# Foreign Keys
#
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
end
