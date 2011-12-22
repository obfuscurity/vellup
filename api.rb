
require 'sinatra'
require 'json'
require 'newrelic_rpm'

require './models/all'

module Vellup
  class API < Sinatra::Base

    configure do
      enable :logging
      enable :method_override
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
      'Application error'
    end

    helpers do
      def check_api_version!
        halt 500 unless request.env['X-API-VERSION'].to_i == 1
      end
      def has_token?
        true
      end
      def authenticate!
        has_token? or halt 401
      end
      def site_owner?(site_uuid)
        @site = Site.filter(:uuid => site_uuid, :owner_id => @user.id, :enabled => true).first || nil
        halt 403 if @site.nil?
      end
    end

#    post '/signup' do
#      @user = User.new(params.merge({ 'site_id' => 1, 'email' => params[:username] }))
#      @user.save
#      status 201, { :message => 'Confirmation instructions sent to your email address' }.to_json
#    end

#    post '/confirm/:token/?' do
#      @user = User.filter(:confirm_token => params[:token], :site_id => 1, :enabled => true, :confirmed => false).first || nil
#      if !@user.nil?
#        if @user.confirmed?
#          halt 410, { :message => 'User already confirmed' }.to_json
#        else
#          @user.confirm
#          @user.save
#          status 204
#        end
#      else
#        halt 404, { :message => 'Asset not found' }.to_json
#      end
#    end

#    get '/confirm/:username' do
#      @user = User.filter(:username => params[:username], :site_id => 1).first || nil
#      if !@user.nil?
#        if @user.confirmed?
#          halt 410, { :message => 'User already confirmed' }.to_json
#        else
#          @user.resend_confirmation
#          status 204
#        end
#      else
#        halt 404, { :message => 'Asset not found' }.to_json
#      end
#    end

#    get '/profile/?' do
#      @user.to_json
#    end

#    put '/profile' do
#      if ((! params[:password1].empty?) || (! params[:password2].empty?))
#        if ((params[:password1] == params[:password2]) and (! params[:password1].empty?))
#          @user.update_password(params[:password1])
#        else
#          halt 401
#        end
#      end
#      %w( password1 password2 ).each {|p| params.delete(p)}
#      @user.update(params)
#      @user.save
#      status 204
#    end

    post '/sites/add' do
      @site = Site.new(:name => params[:name], :owner_id => @user.id).save
      @site.to_json
    end

    get '/sites/?' do
      @sites.to_json
    end

    get '/sites/:uuid/?' do
      @site = Site.filter(:uuid => params[:uuid], :owner_id => @user.id, :enabled => true).first || nil
      if !@site.nil?
        @site.to_json
      else
        halt 404
      end
    end

    delete '/sites/:uuid/?' do
      @site = Site.filter(:uuid => params[:uuid], :owner_id => @user.id, :enabled => true).first || nil
      if !@site.nil?
        @site.destroy
        status 204
      else
        halt 404
      end
    end

    post '/sites/:uuid/users/add' do
      params.delete('uuid')
      @site_user = User.new(params.merge({ 'site_id' => @site.id, 'email' => params[:username], 'confirmed' => true }))
      @site_user.save
      @site_user.to_json
    end

    get '/sites/:uuid/users/?' do
      @site_users = User.from(:users, :sites).where(:users__site_id => :sites__id, :sites__uuid => params[:uuid], :users__enabled => true).select('users.*'.lit, :sites__name.as(:site), :sites__uuid.as(:site_uuid)).order(:id).all
      if !@site_users.empty?
        @site_users.to_json
      else
        halt 404
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
