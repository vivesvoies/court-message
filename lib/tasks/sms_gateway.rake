namespace :sms_gateway do
  desc "Provision a new SMS gateway and print its API token (shown only once)"
  task :provision, [ :name ] => :environment do |_task, args|
    abort "Usage: rake sms_gateway:provision[name]" if args[:name].blank?

    gateway, token = SmsGateway.provision!(name: args[:name])

    puts "SMS gateway ##{gateway.id} \"#{gateway.name}\" created."
    puts "API token (store it on the gateway now, it cannot be displayed again):"
    puts
    puts "  #{token}"
  end

  desc "Rotate the API token of an existing SMS gateway"
  task :rotate_token, [ :name ] => :environment do |_task, args|
    abort "Usage: rake sms_gateway:rotate_token[name]" if args[:name].blank?

    gateway = SmsGateway.find_by!(name: args[:name])
    token = gateway.rotate_token!

    puts "New API token for \"#{gateway.name}\" (the previous token no longer works):"
    puts
    puts "  #{token}"
  end

  desc "Report gateway/modem/queue health issues to the logs and Sentry (run from cron)"
  task check_health: :environment do
    issues = SmsGatewayHealthService.new.issues

    if issues.empty?
      puts "sms_gateway: all healthy"
    else
      issues.each do |issue|
        puts issue
        Rails.logger.warn("[sms_gateway] #{issue}")
        Sentry.capture_message("[sms_gateway] #{issue}", level: issue.severity)
      end
    end
  end

  desc "Re-route stuck or modem-failed messages to their line's fallback (run from cron)"
  task failover: :environment do
    results = MessageFallbackService.new.run!

    if results.empty?
      puts "sms_gateway: nothing to fail over"
    else
      results.each do |result|
        puts "message #{result.message.id} -> #{result.message.phone_line.phone} (#{result.submitted ? 'submitted' : 'FAILED'})"
      end
    end
  end

  desc "Add a phone line (SIM number) to a gateway: rake sms_gateway:add_line[gateway_name,phone]"
  task :add_line, [ :name, :phone ] => :environment do |_task, args|
    abort "Usage: rake sms_gateway:add_line[gateway_name,phone]" if args[:name].blank? || args[:phone].blank?

    gateway = SmsGateway.find_by!(name: args[:name])
    line = gateway.phone_lines.create!(phone: args[:phone], provider: "sms_gateway")

    puts "Phone line ##{line.id} #{line.phone} attached to \"#{gateway.name}\"."
    puts "Attach it to a team (Team#phone_line) or mark it as default to route outbound messages through it."
  end
end
