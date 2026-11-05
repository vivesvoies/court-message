# Prints the stress test report: bin/rails runner script/sms_gateway_stress/report.rb
require_relative "stats"

puts SmsGatewayStress::Stats.new.report
