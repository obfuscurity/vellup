
namespace :db do
  require "sequel"
  namespace :migrate do
    Sequel.extension :migration
    DB = Sequel.connect(ENV['HEROKU_SHARED_POSTGRESQL_URL'] || "postgres://localhost/vellup")

    desc "Perform migration reset (full erase and migration up)"
    task :reset do
      Sequel::Migrator.run(DB, "migrations", :target => 0)
      Sequel::Migrator.run(DB, "migrations")
      puts "<= sq:migrate:reset executed"
    end

    desc "Perform migration up/down to VERSION"
    task :to do
      version = (ENV['version'] || ENV['VERSION']).to_i
      raise "No VERSION was provided" if version.nil?
      Sequel::Migrator.run(DB, "migrations", :target => version)
      puts "<= sq:migrate:to version=[#{version}] executed"
    end

    desc "Perform migration up to latest migration available"
    task :up do
      Sequel::Migrator.run(DB, "migrations")
      puts "<= sq:migrate:up executed"
    end

    desc "Perform migration down (erase all data)"
    task :down do
      Sequel::Migrator.run(DB, "migrations", :target => 0)
      puts "<= sq:migrate:down executed"
    end
  end
end

namespace :queue do
  require "resque/tasks"
  require "./models/all"
  Resque.redis = ENV['REDISTOGO_URL']
  task :work => "resque:work"
end

