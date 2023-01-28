require "test_helper"

class LintFactoriesTest < ActiveSupport::TestCase
  def test_factories
    FactoryBot.lint traits: true
  end
end
