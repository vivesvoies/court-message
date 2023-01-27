require "test_helper"

class FlashHelperTest < ActiveSupport::TestCase
  include FlashHelper
  def test_flash_id
    type = "alert"
    message = "0123456789azertyuiop"
    assert_equal(flash_id(type, message), "alert-0123456789")
  end

  def test_flash_dsrf_class
    assert_equal("fr-alert--info", flash_dsfr_class("notice"))
    assert_equal("fr-alert--info", flash_dsfr_class(:notice))
    assert_equal("fr-alert--error", flash_dsfr_class("alert"))
    assert_equal("fr-alert--success", flash_dsfr_class("success"))
    assert_equal("fr-alert--anything-really", flash_dsfr_class("anything, really"))
  end
end
