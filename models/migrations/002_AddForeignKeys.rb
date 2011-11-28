$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')
require "models"

Sequel.migration do
  up do
    alter_table(:accounts) do
      add_foreign_key(:owner_id, :users)
    end
  end

  down do
    alter_table(:accounts) do
      drop_constraint(:accounts_owner_id_fkey)
      drop_column(:owner_id)
    end
  end
end

