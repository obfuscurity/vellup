require "sequel"

Sequel.connect(ENV['HEROKU_SHARED_POSTGRESQL_URL'])

$LOAD_PATH.unshift File.dirname(__FILE__)
require "sites"
require "users"

Sequel::Model.plugin :json_serializer
User.plugin :json_serializer

