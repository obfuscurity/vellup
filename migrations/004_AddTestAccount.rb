
Sequel.migration do
  up do
    timestamp = Time.now

    self[:users].insert(
      :username      => "rackup-tests@vellup.com",
      :password      => "$2a$10$bOI4tGi4/VCYTWom686qDee3zUk8eu9vrcS4fvumoyXYQiOCeN1RO",
      :email         => "rackup-tests@vellup.com",
      :api_token     => "00000000-0000-0000-0000-000000000000",
      :confirm_token => "00000000-0000-0000-0000-000000000001",
      :site_id       => 1,
      :enabled       => true,
      :confirmed     => true,
      :created_at    => timestamp,
      :updated_at    => timestamp,
      :confirmed_at  => timestamp
    )
  end
end

