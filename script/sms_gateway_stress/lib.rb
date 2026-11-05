# Stress test of the SMS gateway, for staging only. This folder lives on the
# sms-gateway-stress branch and is never deployed to production.
#
# Replays production's rhythm as measured on 2026-06-29..2026-10-27 (1211
# outbound and 676 inbound messages over 120 days): weekday hourly profiles,
# daily volumes, bursts, message lengths and alphabets. Every message is sent
# to a contact whose number is the gateway's own SIM: each SMS the modem sends
# comes back to it as an inbound SMS, so both directions are exercised without
# writing to anyone.
module SmsGatewayStress
  ZONE = ActiveSupport::TimeZone["Europe/Paris"]
  TEAM_SLUG = ENV.fetch("STRESS_TEAM", "stress-passerelle")
  LOOPBACK_PHONE = ENV.fetch("STRESS_LOOPBACK_PHONE", "+33743782865")
  STARTS_AT = ZONE.parse(ENV.fetch("STRESS_FROM", "2026-11-05 20:00"))
  ENDS_AT = ZONE.parse(ENV.fetch("STRESS_UNTIL", "2026-11-08 22:00"))
  # Stop generating after the gateway has been unreachable this long: the
  # fallback is exercised by the first messages, the rest would only spend
  # Vonage credit.
  PAUSE_AFTER_DOWN = ENV.fetch("STRESS_PAUSE_AFTER_DOWN_MINUTES", "30").to_i.minutes
  # Events missed by more than this (worker down, deploy) are skipped, not
  # sent late in a burst that production never produces.
  CATCH_UP = 10.minutes

  # Messages per hour of day (Europe/Paris), production weekdays.
  AGENT_HOURS = { 7 => 22, 8 => 261, 9 => 267, 10 => 75, 11 => 93, 12 => 4, 13 => 130,
                  14 => 81, 15 => 113, 16 => 143, 17 => 22 }.freeze
  USAGER_HOURS = { 6 => 3, 7 => 22, 8 => 61, 9 => 105, 10 => 57, 11 => 61, 12 => 36, 13 => 64,
                   14 => 68, 15 => 53, 16 => 75, 17 => 30, 18 => 5, 19 => 13, 20 => 10, 21 => 6 }.freeze

  # Length quantiles (share of messages => characters) and share of messages
  # needing UCS-2 (a character outside the GSM 03.38 alphabet).
  PROFILES = {
    agent: { lengths: [ [ 0.0, 20 ], [ 0.5, 160 ], [ 0.9, 351 ], [ 1.0, 507 ] ], ucs2: 0.71 },
    usager: { lengths: [ [ 0.0, 2 ], [ 0.5, 53 ], [ 0.9, 182 ], [ 0.98, 400 ], [ 1.0, 941 ] ], ucs2: 0.25 }
  }.freeze

  # Production weekend days are empty: every day replays a weekday. Fri and
  # Sun are p90 days, Sat the busiest day seen (85 + 47), with production's
  # bursts: 13 messages in a minute, 37 in ten minutes.
  # Bursts: [time, messages, spread in minutes], taken from the day's agent volume.
  DAYS = {
    "2026-11-05" => { agent: 6, usager: 4, bursts: [ [ "21:20", 6, 2 ] ], usager_hours: { 21 => 1 } },
    "2026-11-06" => { agent: 31, usager: 15, bursts: [ [ "09:05", 13, 1 ] ] },
    "2026-11-07" => { agent: 85, usager: 47, bursts: [ [ "08:30", 13, 1 ], [ "14:00", 37, 10 ] ] },
    "2026-11-08" => { agent: 31, usager: 15, bursts: [ [ "09:05", 13, 1 ] ] }
  }.freeze

  Event = Struct.new(:ref, :at, :kind, :burst, keyword_init: true)

  REF_PATTERN = /\[(ST-\d{4}-\d{3})\]/

  def self.plan(date)
    spec = DAYS[date.iso8601]
    return [] unless spec

    rng = Random.new(date.strftime("%Y%m%d").to_i)
    events = []
    spec[:bursts].each do |at, count, minutes|
      start = ZONE.parse("#{date} #{at}")
      count.times { events << Event.new(at: start + rng.rand(minutes * 60), kind: :agent, burst: at) }
    end
    (spec[:agent] - spec[:bursts].sum { |_, count, _| count }).times do
      events << Event.new(at: random_time(rng, date, spec[:agent_hours] || AGENT_HOURS), kind: :agent)
    end
    spec[:usager].times do
      events << Event.new(at: random_time(rng, date, spec[:usager_hours] || USAGER_HOURS), kind: :usager)
    end
    events.sort_by!(&:at)
    events.each_with_index { |event, i| event.ref = "ST-#{date.strftime('%m%d')}-#{format('%03d', i + 1)}" }
  end

  def self.all_events
    (STARTS_AT.to_date..ENDS_AT.to_date).flat_map { |date| plan(date) }
      .select { |event| event.at.between?(STARTS_AT, ENDS_AT) }
  end

  def self.random_time(rng, date, hours)
    total = hours.values.sum
    pick = rng.rand(total)
    hour = hours.find { |_, weight| (pick -= weight) < 0 }.first
    ZONE.parse("#{date} #{format('%02d', hour)}:00") + rng.rand(3600)
  end

  def self.team
    Team.find_by!(slug: TEAM_SLUG)
  end

  def self.conversation
    team.contacts.find_by!(phone: LOOPBACK_PHONE).conversation
  end

  def self.line
    PhoneLine.find_by!(phone: LOOPBACK_PHONE)
  end

  def self.stress_messages
    conversation.messages.where("messages.content LIKE ?", "%[ST-%")
  end

  def self.ref_of(message)
    message.content.to_s[REF_PATTERN, 1]
  end

  # Builds French text of the drawn length and alphabet, ending with the
  # event's reference. Deterministic per reference.
  module Text
    GSM = Set.new(
      "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿" \
      "abcdefghijklmnopqrstuvwxyzäöñüà^{}\\[~]|€".chars
    )
    GSM_WORDS = %w[
      bonjour madame monsieur votre dossier rendez-vous demain matin après-midi à la le les de des
      pour avec mairie pièces justificatifs attestation merci bien vouloir apporter carte identité
      avis imposition CAF CPAM permanence accueil lundi mardi mercredi jeudi vendredi heures rappel
      document signé envoyé numéro allocataire aide logement demande complète validée en cours nous
      vous avons est sera été traité appeler contacter possible si besoin cordialement l'équipe ok
      oui non d'accord je viens passer quand dossier février déjà déclaration formulaire photocopie
    ].freeze
    UCS2_WORDS = %w[
      être prêt reçu reçue ça bientôt tâche hôpital impôts coût août connaître l’équipe d’ici
      «dossier» sœur nº fenêtre plutôt même s’il c’est j’ai
    ].freeze
    EMOJI = %w[🙂 👍 🙏].freeze

    def self.build(event)
      rng = Random.new(event.ref.delete("^0-9").to_i)
      profile = PROFILES.fetch(event.kind)
      ucs2 = rng.rand < profile[:ucs2]
      length = quantile(rng.rand, profile[:lengths])
      tag = " [#{event.ref}]"
      words = []
      words << UCS2_WORDS.sample(random: rng) if ucs2
      while words.empty? || words.join(" ").length < length - tag.length
        words << (ucs2 && rng.rand < 0.5 ? (UCS2_WORDS + GSM_WORDS) : GSM_WORDS).sample(random: rng)
      end
      body = words.join(" ")
      body = body[0, [ length - tag.length, 1 ].max].sub(/\s+\S*\z/, "") if body.length > length - tag.length && body.include?(" ")
      body = body.sub(/\A\p{Ll}/, &:upcase)
      body += " #{EMOJI.sample(random: rng)}" if ucs2 && rng.rand < 0.15
      body + tag
    end

    def self.gsm?(text)
      text.each_char.all? { |char| GSM.include?(char) }
    end

    def self.quantile(u, points)
      lower, upper = points.each_cons(2).find { |(p0, _), (p1, _)| u.between?(p0, p1) }
      lower[1] + ((u - lower[0]) / (upper[0] - lower[0]) * (upper[1] - lower[1])).round
    end
  end
end
