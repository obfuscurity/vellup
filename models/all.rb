require 'sequel'
require 'uuid'

Sequel.connect(ENV['HEROKU_SHARED_POSTGRESQL_GOLD_URL'] || 'postgres://localhost/vellup')

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'sites'
require 'users'

