
require 'sequel'
require 'securerandom'

db = ENV['DATABASE_URL'] || 'postgres://localhost/vellup'
Sequel.connect(db)

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'sites'
require 'users'
require 'schemas'

