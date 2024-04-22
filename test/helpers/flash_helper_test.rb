require "test_helper"

class FlashHelperTest < ActiveSupport::TestCase
  include FlashHelper
  def test_flash_id
    type = "alert"
    message = "01234567890123456789012345678901234567890123456789azerty"
    e = "alert-01234567890123456789012345678901234567890123456789"
    assert_equal(flash_id(type, message), e)
  end

  def test_flash_cm_class
    assert_equal("cm-alert--notice cm-alert--info", flash_cm_class("notice"))
    assert_equal("cm-alert--alert cm-alert--warn", flash_cm_class("alert"))
    assert_equal("cm-alert--anything-really", flash_cm_class("anything, really"))
  end
end
