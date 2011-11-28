$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')
require "models"

Sequel.migration do
  up do
    timestamp = Time.now

    self[:accounts].insert(
      :name          => "vellup",
      :enabled       => true,
      :created_at    => timestamp,
      :updated_at    => timestamp
    )

    self[:users].insert(
      :account_id    => 1,
      :username      => "jason@dixongroup.net",
      :password      => "$2a$10$BpKGMuwioxQrfvkS0HPglOq3hTf1tvhY6KDdaFe3UynbxsvHTzDTm",
      :firstname     => "Jason"
      :lastname      => "Dixon",
      :api_token     => "87bdbcb0-fb92-012e-a61c-109addaa2672",
      :confirm_token => "92da4870-fb92-012e-a61c-109addaa2672",
      :enabled       => true,
      :confirmed     => true,
      :created_at    => timestamp,
      :updated_at    => timestamp,
      :confirmed_at  => timestamp
    )
  end

  down do
    self[:accounts].delete(:id => 1).cascade
  end
end

