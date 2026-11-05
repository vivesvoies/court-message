require_relative "lib"

module SmsGatewayStress
  # Measures the test from the database: what was sent, by which line, how
  # long it waited and took, and whether each SMS came back intact.
  class Stats
    # An SMS not back after this long is counted as lost.
    ECHO_DEADLINE = 15.minutes

    attr_reader :outbound, :inbound

    def initialize
      conversation = SmsGatewayStress.conversation
      messages = conversation.messages.where(created_at: STARTS_AT..).includes(:phone_line).order(:created_at).to_a
      @outbound = messages.reject(&:inbound_status?).select { |m| SmsGatewayStress.ref_of(m) }
      @inbound = messages.select(&:inbound_status?)
      @echoes = @inbound.group_by { |m| SmsGatewayStress.ref_of(m) }
      @events = SmsGatewayStress.all_events.index_by(&:ref)
    end

    def summary_line
      "sent=#{outbound.size} via_sim=#{via_sim.size} via_vonage=#{via_vonage.size} queued=#{queued.size} " \
        "failed=#{failed.size} echoed=#{echoed.size} lost=#{lost.size} duplicated=#{duplicated.size} " \
        "altered=#{altered.size} fragments=#{fragments.size} " \
        "echo_s p50=#{pct(echo_latencies, 50)} p95=#{pct(echo_latencies, 95)} max=#{echo_latencies.max&.round}"
    end

    def report
      lines = []
      lines << "Stress test #{STARTS_AT.strftime('%F %R')} -> #{[ Time.current, ENDS_AT ].min.in_time_zone(ZONE).strftime('%F %R')}"
      lines << "Planned events so far: #{@events.values.count { |e| e.at <= Time.current }}, sent: #{outbound.size}"
      lines << ""
      lines << "Outbound"
      lines << "  via SIM: #{via_sim.size}, via Vonage: #{via_vonage.size} (of which failover: #{failed_over.size})"
      lines << "  status: #{outbound.map(&:status).tally}"
      lines << "  waiting in queue (s): #{dist(queue_waits)}"
      lines << "  sending, claim to ack (s): #{dist(send_times)}"
      lines << ""
      lines << "Loopback (inbound)"
      lines << "  echoed: #{echoed.size}/#{echo_candidates.size}, lost: #{lost.size} #{lost.map { |m| SmsGatewayStress.ref_of(m) }.first(20)}"
      lines << "  duplicated: #{duplicated.size} #{duplicated.first(10)}"
      lines << "  altered content: #{altered.size} #{altered.first(10)}"
      lines << "  fragments (inbound without reference): #{fragments.size} #{fragments.map { |m| m.content.truncate(40) }.first(10)}"
      lines << "  round trip, created to received (s): #{dist(echo_latencies)}"
      lines << ""
      lines << "By kind"
      %i[agent usager].each do |kind|
        sent = outbound.select { |m| event_of(m)&.kind == kind }
        lines << "  #{kind}: sent #{sent.size}, echoed #{sent.count { |m| @echoes[SmsGatewayStress.ref_of(m)] }}, " \
                 "round trip (s) #{dist(sent.filter_map { |m| echo_latency(m) })}"
      end
      lines << ""
      lines << "Bursts"
      outbound.group_by { |m| event_of(m)&.burst && "#{m.created_at.in_time_zone(ZONE).to_date} #{event_of(m).burst}" }
        .except(nil).each do |burst, sent|
          start = sent.map(&:created_at).min
          last_ack = sent.select { |m| m.claimed_at || m.phone_line&.vonage_provider? }.map(&:updated_at).max
          last_echo = sent.filter_map { |m| @echoes[SmsGatewayStress.ref_of(m)]&.first&.created_at }.max
          lines << "  #{burst}: #{sent.size} messages, all sent after #{secs(last_ack && last_ack - start)} s, " \
                   "all back after #{secs(last_echo && last_echo - start)} s, via Vonage #{sent.count { |m| m.phone_line&.vonage_provider? }}"
        end
      lines.join("\n")
    end

    def via_sim = outbound.select { |m| m.phone_line&.sms_gateway_provider? }
    def via_vonage = outbound.select { |m| m.phone_line&.vonage_provider? }
    def failed_over = outbound.select { |m| m.provider_info&.key?("fallback") }
    def queued = outbound.select(&:unsent_status?)
    def failed = outbound.select(&:failed_status?)
    def echo_candidates = outbound.reject { |m| m.unsent_status? || m.failed_status? }
    def echoed = echo_candidates.select { |m| @echoes[SmsGatewayStress.ref_of(m)] }

    def lost
      echo_candidates.select { |m| m.created_at < ECHO_DEADLINE.ago && !@echoes[SmsGatewayStress.ref_of(m)] }
    end

    def duplicated = @echoes.select { |ref, list| ref && list.size > 1 }.keys

    def altered
      sent = outbound.index_by { |m| SmsGatewayStress.ref_of(m) }
      @echoes.flat_map { |ref, list| list.reject { |m| sent[ref].nil? || m.content == sent[ref].content }.map { ref } }.uniq
    end

    def fragments = @echoes.fetch(nil, [])

    def queue_waits = via_sim.filter_map { |m| m.claimed_at && m.claimed_at - m.created_at }
    def send_times = via_sim.select(&:submitted_status?).filter_map { |m| m.claimed_at && m.updated_at - m.claimed_at }
    def echo_latencies = outbound.filter_map { |m| echo_latency(m) }

    private

    def event_of(message) = @events[SmsGatewayStress.ref_of(message)]

    def echo_latency(message)
      echo = @echoes[SmsGatewayStress.ref_of(message)]&.first
      echo && echo.created_at - message.created_at
    end

    def dist(values)
      return "n=0" if values.empty?

      "n=#{values.size} p50=#{pct(values, 50)} p95=#{pct(values, 95)} max=#{values.max.round}"
    end

    def pct(values, percentile)
      return nil if values.empty?

      values.sort[((values.size - 1) * percentile / 100.0).round].round
    end

    def secs(value) = value&.round
  end
end
