# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "sms-length", to: "https://ga.jspm.io/npm:sms-length@0.1.2/dist/sms-length.esm.js"
pin "@rolemodel/turbo-confirm", to: "@rolemodel--turbo-confirm.js" # @2.0.2
