require "test_helper"

class LintFactoriesTest < ActiveSupport::TestCase
  FactoryBot.lint traits: true
end