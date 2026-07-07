ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/capybara"
require "minitest/mock"
require "minitest/reporters"
require "ostruct"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
DatabaseCleaner.strategy = :transaction

class ActiveSupport::TestCase
  self.use_transactional_tests = false
  include FactoryBot::Syntax::Methods

  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)
  # parallelize(workers: 1)

  Faker::Config.locale = "fr"

  def fake_number = Faker::PhoneNumber.cell_phone_in_e164

  # Creates a user who is an admin of every team they belong to. Team
  # administration is per-membership now (see #130): there is no global
  # `team_admin` role, so tests express it through the membership role.
  def create_team_admin(**attrs)
    user = create(:user, **attrs)
    user.memberships.update_all(role: "admin")
    user.reload
    user
  end

  def before_setup
    super
    DatabaseCleaner.start
  end

  def after_teardown
    super
    DatabaseCleaner.clean
  end

  def count_queries(&block)
    count = 0

    counter_f = ->(name, started, finished, unique_id, payload) {
      unless %w[CACHE SCHEMA].include?(payload[:name])
        count += 1
      end
    }

    ActiveSupport::Notifications.subscribed(
      counter_f,
      "sql.active_record",
      &block
    )

    count
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
