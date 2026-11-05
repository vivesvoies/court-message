# Records the Vonage number each environment has always sent from as its
# default phone line. Without it, outbound messages carry no phone_line:
# no attribution, and no line for an SMS gateway to fall back to.
# The numbers are copied from PhoneLine.legacy_number on purpose: a
# migration must not change meaning when that method later goes away.
class CreateDefaultVonagePhoneLine < ActiveRecord::Migration[8.1]
  NUMBERS = {
    "production" => "+33644635900",
    "staging" => "+33644639777"
  }.freeze
  DEVELOPMENT_NUMBER = "+33644630057"

  def up
    return if select_value(%(SELECT 1 FROM phone_lines WHERE "default" = true))

    phone = quote(NUMBERS.fetch(Rails.env, DEVELOPMENT_NUMBER))
    execute(<<~SQL.squish)
      INSERT INTO phone_lines (phone, provider, "default", active, created_at, updated_at)
      VALUES (#{phone}, 'vonage', true, true, NOW(), NOW())
      ON CONFLICT (phone) DO NOTHING
    SQL
  end

  def down
    # Kept on rollback: messages may already reference the line.
  end
end
