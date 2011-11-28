## Users

### Primary Columns

* id
* account_id
* email (same as username?)
* username
* password
* firstname
* lastname
* api_token
* confirm_token
* enabled
* confirmed
* created_at
* updated_at
* confirmed_at
* last_login_at

### Secondary Columns (example)

* address1
* address2
* city
* state (or province)
* country
* zip
* phone1
* phone2
* timezone

## Accounts

### Primary Columns

* id
* owner_id references users(id)
* name
* enabled
* created_at
* updated_at

### Secondary Columns (example)

* timezone
* key (for encrypting user data)

## Transactions

* timestamp
* account_id
* user_id
* action_id

## Actions

* id
* name

