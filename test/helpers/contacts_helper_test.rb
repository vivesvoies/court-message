require "test_helper"

class ContactsHelperTest < ActiveSupport::TestCase
  include ContactsHelper
  include ActionView::Helpers::TagHelper

  def test_info_tag
    c = create(:contact)
    assert_equal(
      info_tag(c, key: :name, missing: "missing"),
      "<div class=\"Contact__name\">#{c.name}</div>"
    )

    c.name = "  "
    assert_equal(
      info_tag(c, key: :name, missing: "missing"),
      "<div class=\"Contact__name Contact__name--missing\">missing</div>"
    )
  end
end
