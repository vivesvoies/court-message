# Stress test worker (Procfile "stress" on the sms-gateway-stress branch).
# Sends each planned event when its time comes, through the same steps as
# MessagesController#create, until SmsGatewayStress::ENDS_AT. Logs one line per
# event, gateway availability changes, and a summary every 10 minutes.
#
#   STRESS_DRY_RUN=1 bin/rails runner script/sms_gateway_stress/run.rb
#     prints the plan and every message, checks lengths and alphabets, sends nothing.
require_relative "lib"
require_relative "stats"

module SmsGatewayStress
  class Worker
    SUMMARY_EVERY = 10.minutes

    def initialize
      @events = SmsGatewayStress.all_events
      @skipped = Set.new
      @down_since = nil
      @next_summary = Time.current
      $stdout.sync = true
    end

    def run
      log("start: #{@events.size} events until #{ENDS_AT}, #{@events.count { |e| e.at > Time.current }} still ahead")
      while Time.current < ENDS_AT
        track_gateway
        due.each { |event| process(event) }
        summary if Time.current >= @next_summary
        sleep(seconds_to_next_event)
      end
      summary
      log("end of the stress test")
      sleep # keep the container idle rather than crash-looping
    end

    private

    def due
      now = Time.current
      @events.select { |e| e.at <= now && e.at > now - CATCH_UP && !@skipped.include?(e.ref) }
        .reject { |e| sent?(e) }
    end

    def process(event)
      if paused?
        @skipped << event.ref
        return log("#{event.ref} skipped: gateway unreachable since #{@down_since.in_time_zone(ZONE).strftime('%T')}")
      end

      message = send_message(Text.build(event))
      log("#{event.ref} #{event.kind}#{" burst #{event.burst}" if event.burst} #{message.content.length} chars " \
          "#{Text.gsm?(message.content) ? 'gsm' : 'ucs2'} -> #{message.status} via #{message.phone_line&.phone}")
    rescue => e
      @skipped << event.ref
      log("#{event.ref} error: #{e.class}: #{e.message}")
      Sentry.capture_exception(e)
    end

    # Same steps as MessagesController#create.
    def send_message(content)
      conversation = SmsGatewayStress.conversation
      message = Message.new(conversation:, content:, sender: conversation.team.users.first)
      message.save!
      service = OutboundMessagesService.new(message)
      conversation.messages << message
      service.submit!
      message
    end

    def sent?(event)
      SmsGatewayStress.stress_messages.where.not(status: "inbound")
        .where("messages.content LIKE ?", "%[#{event.ref}]%").exists?
    end

    def track_gateway
      line = SmsGatewayStress.line
      up = line.active? && line.reachable?
      if up && @down_since
        log("gateway back after #{((Time.current - @down_since) / 60).round(1)} min")
        @down_since = nil
      elsif !up && @down_since.nil?
        @down_since = Time.current
        log("gateway unreachable: active=#{line.active?} modem_ok=#{line.modem_ok.inspect} " \
            "seen=#{line.sms_gateway&.last_seen_at&.in_time_zone(ZONE)&.strftime('%T')} details=#{line.modem_details.inspect}")
      end
    end

    def paused?
      @down_since.present? && Time.current - @down_since > PAUSE_AFTER_DOWN
    end

    def seconds_to_next_event
      upcoming = @events.map(&:at).select { |at| at > Time.current }.min
      [ upcoming ? upcoming - Time.current : 60, 30 ].min.clamp(1, 30)
    end

    def summary
      @next_summary = Time.current + SUMMARY_EVERY
      log("summary: #{Stats.new.summary_line}")
    rescue => e
      log("summary error: #{e.class}: #{e.message}")
    end

    def log(text)
      puts "[stress] #{Time.current.in_time_zone(ZONE).strftime('%a %T')} #{text}"
    end
  end

  def self.dry_run
    events = all_events
    events.each do |event|
      text = Text.build(event)
      puts "#{event.at.in_time_zone(ZONE).strftime('%a %T')} #{event.ref} #{event.kind.to_s.ljust(6)} " \
           "#{(event.burst || '').ljust(5)} #{text.length.to_s.rjust(4)} #{Text.gsm?(text) ? 'gsm ' : 'ucs2'} #{text.truncate(90)}"
    end
    by_kind = events.group_by(&:kind)
    by_kind.each do |kind, list|
      texts = list.map { |e| Text.build(e) }
      lengths = texts.map(&:length).sort
      ucs2 = texts.count { |t| !Text.gsm?(t) }
      puts "#{kind}: #{list.size} messages, length p50=#{lengths[lengths.size / 2]} p90=#{lengths[(lengths.size * 0.9).floor]} " \
           "max=#{lengths.max}, ucs2=#{(100.0 * ucs2 / list.size).round}%"
    end
    events.group_by { |e| e.at.in_time_zone(ZONE).to_date }.each { |date, list| puts "#{date}: #{list.size} events" }
  end
end

if ENV["STRESS_DRY_RUN"].present?
  SmsGatewayStress.dry_run
else
  SmsGatewayStress::Worker.new.run
end
