
require 'sinatra'
require 'json'
require 'json-schema'
require 'rfc822'
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
      content_type :json
    end

    after do
    end

    not_found do
      halt 404
    end

    error do
      e = request.env['sinatra.error']
      puts e.to_s
      puts e.backtrace.join('\n')
    end

    helpers do
      def check_api_version!
        halt 400 unless request.env['HTTP_X_API_VERSION'].to_i == 1
      end
      def authenticate!
        api_token = request.env['HTTP_X_API_TOKEN'] || nil
        if !api_token.nil?
          @user = User.filter(:api_token => api_token, :enabled => true, :confirmed => true).first || nil
          halt 401 if @user.nil?
        else
          halt 403 if api_token.nil?
        end
      end
      def is_valid_json?(input)
        begin JSON.parse(input)
          return true
        rescue Exception => e
          return false
        end
      end
      def is_valid_json_schema?(input)
        begin JSON::Validator.validate!(input, nil, :validate_schema => true)
          return true
        rescue Exception => e
          return false
        end
      end
      def passes_schema?(input, schema)
        begin JSON::Validator.validate!(schema.to_json, input.to_json, :validate_schema => true)
          return true
        rescue Exception => e
          return false
        end
      end
    end


    post '/sites/add' do
      if params[:schema]
        halt 400 unless is_valid_json_schema?(params[:schema])
      end
      # XXX Need to implement model-level prepared statements for escaping user input
      @site = Site.new(params.merge({ :owner_id => @user.id })).save || nil
      if !@site.nil?
        status 201
        [:id, :enabled, :visited_at, :owner_id].each {|v| @site.values.delete(v)}
        @site.values.to_json
      else
        halt 400
      end
    end

    get '/sites/?' do
      @sites = []
      Site.select(:uuid, :name, :schema, :created_at, :updated_at).filter(:owner_id => @user.id, :enabled => true).all.each {|s| @sites << s.values}
      if !@sites.empty?
        status 200
        @sites.to_json
      else
        status 204
      end
    end

    get '/sites/:uuid/?' do
      @site = Site.select(:uuid, :name, :schema, :enabled, :created_at, :updated_at).filter(:uuid => :$u, :owner_id => @user.id).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        if @site.enabled?
          @site.values.delete(:enabled)
          status 200
          @site.values.to_json
        else
          halt 410, { :message => 'Site has already been destroyed' }.to_json
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

    delete '/sites/:uuid/?' do
      @site = Site.filter(:uuid => :$u, :owner_id => @user.id).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        if @site.enabled?
          @site.destroy
          status 204
        else
          halt 410, { :message => 'Site has already been destroyed' }.to_json
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

    post '/sites/:uuid/users/add' do
      @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        if !User.username_collision?({ :username => params[:username], :site_id => @site.id })
          if params[:username].is_email?
            params[:custom] ||= ""
            if passes_schema?(JSON.parse(params[:custom]), JSON.parse(@site.values[:schema]))
              confirmed = params[:confirmed] == 'false' ? false : true
              send_confirmation_email = params[:send_confirmation_email] == 'true' ? true : false
              %w( uuid confirmed send_confirmation_email ).each {|p| params.delete(p)}
              # XXX Need to implement model-level prepared statements for escaping user input
              p params
              @site_user = User.new(params.merge({ 'site_id' => @site.id, 'email' => params[:username], 'confirmed' => confirmed })).save || nil
              p @site_user
              if !@site_user.nil?
                @site_user.send_confirmation_email if send_confirmation_email
                [:password, :email, :api_token, :email_is_username, :enabled, :site_id].each {|v| @site_user.values.delete(v)}
                @site_user.values.delete(:confirm_token) if confirmed
                status 201
                @site_user.values.to_json
              else
                halt 400
              end
            else
              halt 400, { :message => 'Does not pass schema specification' }.to_json
            end
          else
            halt 400, { :message => 'Invalid username/email format, see RFC822' }.to_json
          end
        else
          halt 410, { :message => 'Username already taken' }.to_json
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

    post '/sites/:uuid/users/confirm' do
      @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        @site_user = User.filter(:confirm_token => :$t, :site_id => @site.id, :enabled => true).call(:first, :t => params[:confirm_token])
        if !@site_user.nil?
          if !@site_user.confirmed?
            @site_user.confirm
            @site_user.save
            [:password, :email, :api_token, :confirm_token, :email_is_username, :enabled, :site_id].each {|v| @site_user.values.delete(v)}
            status 200
            @site_user.values.to_json
          else
            halt 304
          end
        else
          halt 404, { :message => 'User not found' }.to_json
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

    get '/sites/:uuid/users/?' do
      @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        @site_users = []
        User.select(:users__id, :users__username, :users__custom, :users__confirmed, :users__created_at, :users__updated_at, :users__confirmed_at, :users__authenticated_at, :users__visited_at).from(:users, :sites).where(:users__site_id => :sites__id, :sites__uuid => :$u, :sites__enabled => true, :users__enabled => true).order(:users__id).call(:all, :u => params[:uuid]).each {|u| @site_users << u.values}
        if !@site_users.empty?
          status 200
          @site_users.to_json
        else
          status 204
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

    get '/sites/:uuid/users/:id/?' do
      @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        @site_user = User.select(:id, :username, :custom, :confirmed, :created_at, :updated_at, :confirmed_at, :authenticated_at, :visited_at).where(:id => :$i, :site_id => @site.id, :enabled => true).call(:first, :i => params[:id]) || nil
        if !@site_user.nil?
          @site_user.values.to_json
        else
          halt 404, { :message => 'User not found' }.to_json
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

    put '/sites/:uuid/users/:id' do
      @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        @site_user = User.filter(:id => :$i, :site_id => @site.id, :enabled => true).call(:first, :i => params[:id]) || nil
        if !@site_user.nil?
          if !params[:password].nil?
            if !params[:password].empty?
              @site_user.update_password(params[:password])
            else
              halt 400, { :message => 'Password cannot be an empty string' }.to_json
            end
          end
          # XXX This will go away once we support custom json schemas
          %w( uuid id username password confirmed enabled created_at updated_at confirmed_at authenticated_at visited_at ).each {|p| params.delete(p)}
          @site_user.update(params)
          @site_user.save
          status 200
          [ :password, :email, :api_token, :confirm_token, :email_is_username, :enabled, :site_id ].each {|k| @site_user.values.delete(k)}
          @site_user.values.to_json
        else
          halt 404, { :message => 'User not found' }.to_json
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

    delete '/sites/:uuid/users/:id' do
      @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        @site_user = User.filter(:id => :$i, :site_id => @site.id).call(:first, :i => params[:id]) || nil
        if !@site_user.nil?
          if @site_user.enabled?
            @site_user.destroy
            status 204
          else
            halt 410, { :message => 'User has already been destroyed' }.to_json
          end
        else
          halt 404, { :message => 'User not found' }.to_json
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

    post '/sites/:uuid/users/auth' do
      @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => params[:uuid]) || nil
      if !@site.nil?
        @site_user = User.authenticate(params.merge({ :site => @site.id  })) || nil
        if !@site_user.nil?
          status 200
          [ :password, :email, :api_token, :confirm_token, :email_is_username, :enabled, :site_id ].each {|k| @site_user.values.delete(k)}
          @site_user.values.to_json
        else
          halt 401, { :message => 'Authentication failed' }.to_json
        end
      else
        halt 404, { :message => 'Site not found' }.to_json
      end
    end

  end
end
