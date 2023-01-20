ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "./capybara"
require "minitest/mock"
require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
DatabaseCleaner.strategy = :transaction

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  Faker::Config.locale = "fr"

  def fake_number = Faker::PhoneNumber.cell_phone_in_e164

  def before_setup
    super
    DatabaseCleaner.start
  end

  def after_teardown
    super
    DatabaseCleaner.clean
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
