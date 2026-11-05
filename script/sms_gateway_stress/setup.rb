# Prepares staging for the stress test, idempotently:
#   bin/rails runner script/sms_gateway_stress/setup.rb
# A dedicated team (so the test does not flood a real team's inbox), a robot
# sender, a contact whose number is the SIM itself (loopback), and the SIM
# line, active, falling back to the Vonage default line, routed for this team
# only.
require_relative "lib"

raise "staging only" if Rails.env.production?

line = PhoneLine.find_by!(phone: SmsGatewayStress::LOOPBACK_PHONE)
vonage = PhoneLine.default_line
line.update!(active: true, fallback_phone_line: vonage,
  fallback_after_minutes: ENV.fetch("STRESS_FALLBACK_AFTER_MINUTES", "15").to_i)

team = Team.find_or_create_by!(slug: SmsGatewayStress::TEAM_SLUG) { |t| t.name = "Stress passerelle SMS" }
team.update!(phone_line: line)

robot = User.find_or_initialize_by(email: "stress-passerelle@court-message.fr")
if robot.new_record?
  robot.assign_attributes(name: "Robot stress passerelle", password: SecureRandom.base58(32))
  robot.skip_confirmation!
  robot.save!
end
Membership.find_or_create_by!(team:, user: robot)

contact = team.contacts.find_or_create_by!(phone: SmsGatewayStress::LOOPBACK_PHONE) do |c|
  c.name = "Boucle SIM (stress)"
end
contact.create_conversation! unless contact.conversation

puts "[stress-setup] team=#{team.slug} robot=#{robot.id} contact=#{contact.id} conversation=#{contact.conversation.id} " \
     "line=#{line.phone} active=#{line.active} fallback=#{line.fallback_phone_line&.phone} after=#{line.fallback_after_minutes}min " \
     "route=#{PhoneLine.route_for(team)&.phone}"
