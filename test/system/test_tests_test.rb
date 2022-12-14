require "application_system_test_case"

class TestTestsTest < ApplicationSystemTestCase
  test "visiting the index" do
    visit users_url
  
    assert_text "Users"
  end
end
