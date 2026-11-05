web: bundle exec puma -C config/puma.rb
postdeploy: bundle exec rake db:migrate
stress: bundle exec rails runner script/sms_gateway_stress/run.rb
