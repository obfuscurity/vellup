
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
      puts e.backtrace.join("\n")
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
      def site_owner?(site_uuid)
        @site = Site.filter(:uuid => site_uuid, :owner_id => @user.id, :enabled => true).first || nil
        halt 403 if @site.nil?
      end
    end


    post '/sites/add' do
      @site = Site.new(:name => params[:name], :owner_id => @user.id).save || nil
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
      Site.select(:uuid, :name, :created_at, :updated_at).filter(:owner_id => @user.id, :enabled => true).all.each {|s| @sites << s.values}
      if !@sites.empty?
        status 200
        @sites.to_json
      else
        status 204
      end
    end

    get '/sites/:uuid/?' do
      @site = Site.select(:uuid, :name, :created_at, :updated_at).filter(:uuid => params[:uuid], :owner_id => @user.id).first || nil
      if !@site.nil?
        if @site.enabled?
          status 200
          @site.values.to_json
        else
          halt 410, 'Site has already been destroyed'
        end
      else
        halt 404
      end
    end

    delete '/sites/:uuid/?' do
      @site = Site.filter(:uuid => params[:uuid], :owner_id => @user.id).first || nil
      if !@site.nil?
        if @site.enabled?
          @site.destroy
          status 204
        else
          halt 410, 'Site has already been destroyed'
        end
      else
        halt 404
      end
    end

    post '/sites/:uuid/users/add' do
      @site = Site.filter(:uuid => params[:uuid], :owner_id => @user.id, :enabled => true).first || nil
      if !@site.nil?
        params.delete('uuid')
        @site_user = User.new(params.merge({ 'site_id' => @site.id, 'email' => params[:username], 'confirmed' => true })).save || nil
        if !@site_user.nil?
          [:id, :password, :email, :api_token, :confirm_token, :email_is_username, :enabled, :site_id].each {|v| @site_user.values.delete(v)}
          status 201
          @site_user.values.to_json
        else
          halt 400
        end
      else
        halt 412, 'Site does not exist'
      end
    end

    get '/sites/:uuid/users/?' do
      @site_users = []
      User.select(:users__username, :users__firstname, :users__lastname, :users__confirmed, :users__created_at, :users__updated_at, :users__confirmed_at, :users__authenticated_at, :users__visited_at).from(:users, :sites).where(:users__site_id => :sites__id, :sites__uuid => params[:uuid], :sites__enabled => true, :users__enabled => true).order(:users__id).all.each {|u| @site_users << u.values}
      if !@site_users.empty?
        status 200
        @site_users.to_json
      else
        status 204
      end
    end

    get '/sites/:uuid/users/:id/?' do
      @site_user = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@site_user.nil?
        @site_user.to_json
      else
        halt 404
      end
    end

    put '/sites/:uuid/users/:id' do
      @site_user = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@site_user.nil?
        if ((! params[:password1].empty?) || (! params[:password2].empty?))
          if ((params[:password1] == params[:password2]) and (! params[:password1].empty?))
            @site_user.update_password(params[:password1])
          else
            halt 401
          end
        end
        %w( password1 password2 uuid id ).each {|p| params.delete(p)}
        @site_user.update(params)
        @site_user.save
        @site_user.to_json
      else
        halt 404
      end
    end

    delete '/sites/:uuid/users/:id' do
      @site_user = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@site_user.nil?
        @site_user.destroy
        status 204
      else
        halt 404
      end
    end

  end
end
