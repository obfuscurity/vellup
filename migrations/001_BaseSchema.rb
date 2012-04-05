
Sequel.migration do
  up do
    create_table(:sites) do
      primary_key :id
      String      :uuid,          :size => 32, :null => false, :unique => true
      String      :name,          :size => 50, :null => false
      String      :schema,                     :null => true,  :text => true
      TrueClass   :enabled,                    :null => false, :default => false
      DateTime    :created_at,                 :null => false
      DateTime    :updated_at,                 :null => false
      DateTime    :visited_at,                 :null => false
    end

    create_table(:users) do
      primary_key :id
      String      :username,      :size => 60, :null => false
      String      :password,      :size => 80, :null => false
      String      :email,         :size => 60, :null => false
      String      :custom,                     :null => true,  :text => true
      String      :api_token,     :size => 32, :null => false
      String      :confirm_token, :size => 32, :null => false
      TrueClass   :email_is_username,          :null => false, :default => true
      TrueClass   :enabled,                    :null => false, :default => false
      TrueClass   :confirmed,                  :null => false, :default => false
      DateTime    :created_at,                 :null => false
      DateTime    :updated_at,                 :null => false
      DateTime    :confirmed_at,               :null => true
      DateTime    :authenticated_at,           :null => true
      DateTime    :visited_at,                 :null => true
      foreign_key :site_id, :sites, :deferrable => true
    end

    create_table(:sessions) do
      String      :token,         :size => 64, :null => false, :unique => true
      column      :created_at, "timestamp with time zone", :null => false
      column      :expires_at, "timestamp with time zone", :null => false
      foreign_key :user_id, :users
    end
  end

  down do
    drop_table(:sessions, :sites, :users, :cascade => true)
  end
end

