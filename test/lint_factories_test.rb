require "test_helper"

class LintFactoriesTest < ActiveSupport::TestCase
  def test_factories
    unless ENV["CI"]
      FactoryBot.lint traits: true
    end
  end
end
