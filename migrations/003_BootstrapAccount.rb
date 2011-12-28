
Sequel.migration do
  up do
    timestamp = Time.now

    self[:users].insert(
      :username      => "jason@dixongroup.net",
      :password      => "$2a$10$BpKGMuwioxQrfvkS0HPglOq3hTf1tvhY6KDdaFe3UynbxsvHTzDTm",
      :email         => "jason@dixongroup.net",
      :custom        => "{\"firstname\":\"Jason\",\"lastname\":\"Dixon\"}",
      :api_token     => "87bdbcb0-fb92-012e-a61c-109addaa2672",
      :confirm_token => "92da4870-fb92-012e-a61c-109addaa2672",
      :site_id       => 1,
      :enabled       => true,
      :confirmed     => true,
      :created_at    => timestamp,
      :updated_at    => timestamp,
      :confirmed_at  => timestamp
    )

    self[:sites].insert(
      :uuid          => "2d9774c00d9a012f82c6482a143ef0a0",
      :owner_id      => 1,
      :name          => "vellup",
      :schema        => "{\"name\":\"User\",\"properties\":{\"firstname\":{\"description\":\"Name\",\"type\":\"string\",\"required\":false},\"lastname\":{\"description\":\"Surname\",\"type\":\"string\",\"required\":false}}}",
      :enabled       => true,
      :created_at    => timestamp,
      :updated_at    => timestamp,
      :visited_at    => timestamp
    )
  end
end

