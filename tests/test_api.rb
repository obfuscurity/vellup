
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

  def test_00_create_site
    "Creating a test site"
    post '/sites/add', {:name => 'test_site'}, @@options
    @@site = JSON.parse(last_response.body)
    assert last_response.status == 201
    assert_equal @@site['name'], 'test_site'
  end

  def test_01_modify_site
    "Modifying the name of our test site"
    put "/sites/#{@@site['uuid']}", {:name => 'renamed_site'}, @@options
    @@site = JSON.parse(last_response.body)
    assert last_response.status == 200
    assert_equal @@site['name'], 'renamed_site'
  end

  def test_02_create_user
    "Creating a user for our test site"
    post "/sites/#{@@site['uuid']}/users/add", {:username => 'test_site_user@vellup.com', :password => 'test'}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 201
    assert_equal @@site_user['username'], 'test_site_user@vellup.com'
    assert @@site_user['custom'].nil?
  end

  def test_03_list_users
    "Listing all users for our test site"
    get "/sites/#{@@site['uuid']}/users", {}, @@options
    assert last_response.status = 200
    assert JSON.parse(last_response.body).count == 1
  end

  def test_04_modify_user
    "Modifying the custom data blob of our test user"
    put "/sites/#{@@site['uuid']}/users/#{@@site_user['id']}", {:custom => '{"firstname":"Test","lastname":"Tester"}'}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 200
    assert_equal JSON.parse(@@site_user['custom'])['firstname'], 'Test'
    assert_equal JSON.parse(@@site_user['custom'])['lastname'], 'Tester'
  end

  def test_05_get_user
    "Get the details of our test user"
    get "/sites/#{@@site['uuid']}/users/#{@@site_user['id']}", {}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 200
    assert_equal JSON.parse(@@site_user['custom'])['firstname'], 'Test'
    assert_equal JSON.parse(@@site_user['custom'])['lastname'], 'Tester'
  end

  def test_06_auth_user
    "Authenticating our test user"
    post "/sites/#{@@site['uuid']}/users/auth", {:username => 'test_site_user@vellup.com', :password => 'test'}, @@options
    assert last_response.status == 200
    assert_equal @@site_user['username'], 'test_site_user@vellup.com'
  end

  def test_07_auth_user_bad_password
    "Authentication should fail for our test user"
    post "/sites/#{@@site['uuid']}/users/auth", {:username => 'test_site_user@vellup.com', :password => 'fail'}, @@options
    assert last_response.status == 401
  end

  def test_08_delete_user
    "Deleting our test user"
    delete "/sites/#{@@site['uuid']}/users/#{@@site_user['id']}", {}, @@options
    assert last_response.status == 204
    user = User[@@site_user['id']]
    assert user.values[:enabled] == false
  end

  def test_09_get_invalid_user
    "Attempt to get user details should fail"
    get "/sites/#{@@site['uuid']}/users/#{@@site_user['id']}", {}, @@options
    assert last_response.status == 404
  end

  def test_10_list_users
    "Listing all users for our test site (should return zero)"
    get "/sites/#{@@site['uuid']}/users", {}, @@options
    assert last_response.status = 204
    assert last_response.body.empty?
  end

  def test_11_delete_site
    "Deleting our test site"
    delete "/sites/#{@@site['uuid']}", {}, @@options
    assert last_response.status == 204
    site = Site.filter(:uuid => @@site['uuid']).first
    assert site.values[:enabled] == false
  end

  def test_12_get_invalid_site
    "Attempt to get site details should fail"
    get "/sites/#{@@site['uuid']}", {}, @@options
    assert last_response.status == 404
  end

  def test_13_teardown_user
    "Deleting our test user FOR REAL"
    user = User[@@site_user['id']]
    user.really_destroy
  end

  def test_14_teardown_site
    "Deleting our test site FOR REAL"
    site = Site.filter(:uuid => @@site['uuid']).first
    site.really_destroy
  end
end
