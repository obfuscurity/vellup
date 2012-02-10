
require 'sequel'
require 'uuid'

Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/vellup')

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'sites'
require 'users'
require 'schemas'

