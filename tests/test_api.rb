
require './api'
require 'test/unit'
require 'rack/test'

class VellupApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  @@options = {
    "HTTP_X_API_VERSION" => 1,
    "HTTP_X_API_TOKEN" => "00000000-0000-0000-0000-000000000000"
  }

  @@site = {}
  @@site_user = {}

  def app
    Vellup::API.new
  end

  def test_00_create_site_no_auth
    "Creating a test site without a token should fail"
    post '/sites/add', {:name => 'test_site'}, {}
    assert last_response.status == 400
  end

  def test_00_create_site_missing_name
    "Creating a test site should fail without a name"
    post '/sites/add', {}, @@options
    assert last_response.status == 400
  end

  def test_01_create_site_short_name
    "Creating a test site should fail with a name too short"
    post '/sites/add', {:name => 'x'}, @@options
    assert last_response.status == 400
  end

  def test_02_create_site
    "Creating a test site"
    post '/sites/add', {:name => 'test_site'}, @@options
    @@site = JSON.parse(last_response.body)
    assert last_response.status == 201
    assert_equal @@site['name'], 'test_site'
  end

  def test_03_get_site_unknown
    "Getting unknown site details should fail"
    get "/sites/xxxxxx", {}, @@options
    assert last_response.status == 404
  end

  def test_04_get_site
    "Attempt to get site details"
    get "/sites/#{@@site['uuid']}", {}, @@options
    assert last_response.status == 200
    assert_equal @@site['name'], 'test_site'
  end

  def test_05_modify_site_short_name
    "Modifying our test site should fail with a name too short"
    put "/sites/#{@@site['uuid']}", {:name => 'x'}, @@options
    assert last_response.status == 400
  end

  def test_06_modify_site
    "Modifying the name of our test site"
    put "/sites/#{@@site['uuid']}", {:name => 'renamed_site'}, @@options
    @@site = JSON.parse(last_response.body)
    assert last_response.status == 200
    assert_equal @@site['name'], 'renamed_site'
  end

  def test_07_create_user_missing_username
    "Creating a user should fail without a username"
    post "/sites/#{@@site['uuid']}/users/add", {:password => 'test'}, @@options
    assert last_response.status == 400
  end

  def test_08_create_user_short_username
    "Creating a user should fail with a username too short"
    post "/sites/#{@@site['uuid']}/users/add", {:username => 'x', :password => 'test'}, @@options
    assert last_response.status == 400
  end

  def test_09_create_user_invalid_username
    "Creating a user should fail with an invalid username"
    post "/sites/#{@@site['uuid']}/users/add", {:username => 'xx', :password => 'test'}, @@options
    assert last_response.status == 400
  end

  def test_10_create_user_missing_password
    "Creating a user should fail without a password"
    post "/sites/#{@@site['uuid']}/users/add", {:username => 'test_site_user@vellup.com'}, @@options
    assert last_response.status == 400
  end

  def test_11_create_user_invalid_password
    "Creating a user should fail with an invalid password"
    post "/sites/#{@@site['uuid']}/users/add", {:username => 'test_site_user@vellup.com', :password => 'x'}, @@options
    assert last_response.status == 400
  end

  def test_12_create_user
    "Creating a user for our test site"
    post "/sites/#{@@site['uuid']}/users/add", {:username => 'test_site_user@vellup.com', :password => 'test'}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 201
    assert_equal @@site_user['username'], 'test_site_user@vellup.com'
    assert JSON.parse(@@site_user['custom']).is_a?(Hash)
    assert JSON.parse(@@site_user['custom']).empty?
  end

  def test_13_list_users
    "Listing all users for our test site"
    get "/sites/#{@@site['uuid']}/users", {}, @@options
    assert last_response.status = 200
    assert JSON.parse(last_response.body).count == 1
  end

  #def test_XX_modify_user_invalid_json
  #"Modifying the custom data blob of our test user with invalid data should fail"
  #  put "/sites/#{@@site['uuid']}/users/#{@@site_user['id']}", {:custom => '{"firstname":"Test","lastname":"Tester"}'}, @@options
  #  assert last_response.status == 400
  #end

  def test_14_modify_user
    "Modifying the custom data blob of our test user"
    put "/sites/#{@@site['uuid']}/users/#{@@site_user['username']}", {:custom => '{"firstname":"Test","lastname":"Tester"}'}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 200
    assert_equal JSON.parse(@@site_user['custom'])['firstname'], 'Test'
    assert_equal JSON.parse(@@site_user['custom'])['lastname'], 'Tester'
  end

  def test_15_get_user_unknown
    "Getting the details of an unknown test user should fail"
    get "/sites/#{@@site['uuid']}/users/00", {}, @@options
    assert last_response.status == 404
  end

  def test_16_get_user
    "Getting the details of our test user"
    get "/sites/#{@@site['uuid']}/users/#{@@site_user['username']}", {}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 200
    assert_equal JSON.parse(@@site_user['custom'])['firstname'], 'Test'
    assert_equal JSON.parse(@@site_user['custom'])['lastname'], 'Tester'
  end

  def test_17_auth_user_bad_password
    "Authentication should fail for our test user"
    post "/sites/#{@@site['uuid']}/users/auth", {:username => 'test_site_user@vellup.com', :password => 'fail'}, @@options
    assert last_response.status == 401
  end

  def test_18_auth_user
    "Authenticating our test user"
    post "/sites/#{@@site['uuid']}/users/auth", {:username => 'test_site_user@vellup.com', :password => 'test'}, @@options
    assert last_response.status == 200
    assert_equal @@site_user['username'], 'test_site_user@vellup.com'
  end

  def test_19_delete_user
    "Deleting our test user"
    delete "/sites/#{@@site['uuid']}/users/#{@@site_user['username']}", {}, @@options
    assert last_response.status == 204
    user = User[@@site_user['id']]
    assert user.values[:enabled] == false
  end

  def test_20_get_invalid_user
    "Getting user details should fail after deleting user"
    get "/sites/#{@@site['uuid']}/users/#{@@site_user['username']}", {}, @@options
    assert last_response.status == 404
  end

  def test_21_list_users
    "Listing all users for our test site (should return zero)"
    get "/sites/#{@@site['uuid']}/users", {}, @@options
    assert last_response.status = 204
    assert last_response.body.empty?
  end

  def test_22_delete_site
    "Deleting our test site"
    delete "/sites/#{@@site['uuid']}", {}, @@options
    assert last_response.status == 204
    site = Site.filter(:uuid => @@site['uuid']).first
    assert site.values[:enabled] == false
  end

  def test_23_get_invalid_site
    "Getting site details should fail after deleting site"
    get "/sites/#{@@site['uuid']}", {}, @@options
    assert last_response.status == 404
  end

  def test_24_teardown_user
    "Deleting our test user FOR REAL"
    user = User[@@site_user['id']]
    user.really_destroy
  end

  def test_25_teardown_site
    "Deleting our test site FOR REAL"
    site = Site.filter(:uuid => @@site['uuid']).first
    site.really_destroy
  end
end
