class Avo::Actions::FailOverPhoneLine < Avo::BaseAction
  self.name = "Désactiver et basculer vers la ligne de secours"
  self.message = "Désactive la ligne et renvoie immédiatement ses messages en attente (jamais réclamés) et ses envois échoués par la ligne de secours. Les messages réclamés mais non confirmés ne sont pas renvoyés (risque de doublon)."

  def handle(**args)
    query = args[:query]

    query.each do |line|
      if line.fallback_phone_line.nil?
        error "#{line.phone} : pas de ligne de secours configurée."
        next
      end

      line.update!(active: false)
      results = MessageFallbackService.new([ line ]).run!
      succeed "#{line.phone} désactivée, #{results.count(&:submitted)}/#{results.size} message(s) basculé(s) vers #{line.fallback_phone_line.phone}."
    end
  end
end
