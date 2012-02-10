
Sequel.migration do
  up do
    alter_table(:sites) do
      add_foreign_key(:owner_id, :users)
    end
  end

  down do
    alter_table(:sites) do
      drop_constraint(:sites_owner_id_fkey)
      drop_column(:owner_id)
    end
  end
end

