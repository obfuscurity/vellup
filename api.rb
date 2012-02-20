require 'sinatra'
require 'json'
require 'newrelic_rpm'

require './models/all'

module Vellup
  class API < Sinatra::Base

    configure do
      enable :logging
      disable :raise_errors
      disable :show_exceptions
      set :port, ENV['PORT'] || 4568
    end

    before do
      check_api_version!
      authenticate!
      User.raise_on_typecast_failure = false
      User.strict_param_setting = false
      Site.strict_param_setting = false
      content_type :json
    end

    after do
    end

    not_found do
      halt 404
    end

    error do
      e = request.env['sinatra.error']
      # only grab the first possible error
      error = e.message.split(',').first
      halt 400, { :message => error }.to_json
    end

    helpers do
      def check_api_version!
        halt 400, { :message => 'missing X_API_VERSION' }.to_json unless (request.env['HTTP_X_API_VERSION'].to_i == 1)
      end
      def authenticate!
        @user = User.filter(:api_token => :$t, :enabled => true, :confirmed => true).call(:first, :t => request.env['HTTP_X_API_TOKEN'])
        halt 401, { :message => 'incorrect or expired token' }.to_json if @user.nil?
      end
      def validate_site(uuid)
        @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => uuid)
        halt 404, { :message => 'site not found' }.to_json if @site.nil?
      end
      def validate_site_user(id)
        @site_user = User.filter(:id => :$i, :site_id => @site.id, :enabled => true).call(:first, :i => id)
        halt 404, { :message => 'user not found' }.to_json if @site_user.nil?
      end
    end


    post '/sites/add' do
      @site = Site.new(params.merge({ :owner_id => @user.id })).save
      status 201
      [:uuid, :name, :created_at, :updated_at, :schema].inject({}) do |v,k| v[k] = @site.values[k]; v; end.to_json
    end

    get '/sites/?' do
      @sites = []
      Site.select(:uuid, :name, :schema, :created_at, :updated_at).filter(:owner_id => @user.id, :enabled => true).all.each {|s| @sites << s.values}
      status 204 if @sites.empty?
      @sites.to_json
    end

    get '/sites/:uuid/?' do
      validate_site(params[:uuid])
      @site.values.to_json
    end

    put '/sites/:uuid/?' do
      validate_site(params[:uuid])
      @site.update(params)
      @site.save
      [:uuid, :name, :created_at, :updated_at, :schema].inject({}) do |v,k| v[k] = @site.values[k]; v; end.to_json
    end

    delete '/sites/:uuid/?' do
      validate_site(params[:uuid])
      @site.destroy
      status 204
    end

    post '/sites/:uuid/users/add' do
      validate_site(params[:uuid])
      @site_user = User.new(params.merge({ 'site_id' => @site.id, 'email' => params[:username] })).save
      [:password, :email, :api_token, :email_is_username, :enabled, :site_id].each {|v| @site_user.values.delete(v)}
      @site_user.values.delete(:confirm_token) if @site_user.confirmed
      status 201
      @site_user.values.to_json
    end

    post '/sites/:uuid/users/confirm' do
      validate_site(params[:uuid])
      @site_user = User.filter(:confirm_token => :$t, :site_id => @site.id, :enabled => true).call(:first, :t => params[:confirm_token])
      halt 404, { :message => 'user not found' }.to_json if @site_user.nil?
      halt 304, { :message => 'user already confirmed' }.to_json if @site_user.confirmed?
      @site_user.confirm
      @site_user.save
      [:password, :email, :api_token, :confirm_token, :email_is_username, :enabled, :site_id].each {|v| @site_user.values.delete(v)}
      @site_user.values.to_json
    end

    get '/sites/:uuid/users/?' do
      validate_site(params[:uuid])
      @site_users = []
      User.select(:users__id, :users__username, :users__custom, :users__confirmed, :users__created_at, :users__updated_at, :users__confirmed_at, :users__authenticated_at, :users__visited_at).from(:users, :sites).where(:users__site_id => :sites__id, :sites__uuid => :$u, :sites__enabled => true, :users__enabled => true).order(:users__id).call(:all, :u => params[:uuid]).each {|u| @site_users << u.values}
      status 204 if @site_users.empty?
      @site_users.to_json
    end

    get '/sites/:uuid/users/:id/?' do
      validate_site(params[:uuid])
      validate_site_user(params[:id])
      @site_user.values.to_json
    end

    put '/sites/:uuid/users/:id' do
      validate_site(params[:uuid])
      validate_site_user(params[:id])
      @site_user.update_password(params[:password]) if params[:password]
      @site_user.update(:custom => params[:custom]) if params[:custom]
      @site_user.save
      [ :password, :email, :api_token, :confirm_token, :email_is_username, :enabled, :site_id ].each {|k| @site_user.values.delete(k)}
      @site_user.values.to_json
    end

    delete '/sites/:uuid/users/:id' do
      validate_site(params[:uuid])
      validate_site_user(params[:id])
      @site_user.destroy
      status 204
    end

    post '/sites/:uuid/users/auth' do
      validate_site(params[:uuid])
      @site_user = User.authenticate(params.merge({ :site => @site.id  })) || nil
      halt 401 if @site_user.nil?
      [ :password, :email, :api_token, :confirm_token, :email_is_username, :enabled, :site_id ].each {|k| @site_user.values.delete(k)}
      @site_user.values.to_json
    end
  end
end
