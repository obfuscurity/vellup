
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
    post '/sites/add', {:name => 'test_site'}, @@options
    @@site = JSON.parse(last_response.body)
    assert last_response.status == 201
  end

  def test_01_modify_site
    put "/sites/#{@@site['uuid']}", {:name => 'renamed_site'}, @@options
    @@site = JSON.parse(last_response.body)
    assert last_response.status == 200
    assert_equal @@site['name'], 'renamed_site'
  end

  def test_02_create_user
    post "/sites/#{@@site['uuid']}/users/add", {:username => 'test_site_user@vellup.com', :password => 'test'}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 201
    assert_equal @@site_user['username'], 'test_site_user@vellup.com'
    assert @@site_user['custom'].nil?
  end

  def test_03_list_users
    get "/sites/#{@@site['uuid']}/users", {}, @@options
    assert last_response.status = 200
    assert JSON.parse(last_response.body).count == 1
  end

  def test_04_modify_user
    put "/sites/#{@@site['uuid']}/users/#{@@site_user['id']}", {:custom => '{"firstname":"Test","lastname":"Tester"}'}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 200
  end

  def test_05_get_user
    get "/sites/#{@@site['uuid']}/users/#{@@site_user['id']}", {}, @@options
    @@site_user = JSON.parse(last_response.body)
    assert last_response.status == 200
    assert !@@site_user['custom'].nil?
  end

  def test_06_auth_user
    post "/sites/#{@@site['uuid']}/users/auth", {:username => 'test_site_user@vellup.com', :password => 'test'}, @@options
    assert last_response.status == 200
    assert_equal @@site_user['username'], 'test_site_user@vellup.com'
  end

  def test_07_delete_user
    delete "/sites/#{@@site['uuid']}/users/#{@@site_user['id']}", {}, @@options
    assert last_response.status == 204
    user = User[@@site_user['id']]
    assert user.values[:enabled] == false
  end

  def test_08_list_users
    get "/sites/#{@@site['uuid']}/users", {}, @@options
    assert last_response.status = 204
    assert last_response.body.empty?
  end

  def test_09_delete_site
    delete "/sites/#{@@site['uuid']}", {}, @@options
    assert last_response.status == 204
    site = Site.filter(:uuid => @@site['uuid']).first
    assert site.values[:enabled] == false
  end

  def test_10_teardown_user
    user = User[@@site_user['id']]
    user.really_destroy
  end

  def test_11_teardown_site
    site = Site.filter(:uuid => @@site['uuid']).first
    site.really_destroy
  end
end
