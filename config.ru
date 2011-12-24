$LOAD_PATH.unshift File.dirname(__FILE__)

if ENV['APP_NAME'] == 'web'
  require 'web'
  run Vellup::Web
else
  require 'api'
  run Vellup::API
end
