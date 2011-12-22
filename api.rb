
require "sinatra"
require "newrelic_rpm"

require "./models/all"

module Vellup
  class API < Sinatra::Base

    configure do
      enable :logging
      enable :method_override
    end

    before do
      authenticate!
    end

    after do
    end

    not_found do
      json :not_found
    end

    error do
      e = request.env['sinatra.error']
      puts e.to_s
      puts e.backtrace.join("\n")
      "Application error"
    end

    helpers do
      def has_token?
        true
      end
      def authenticate!
        has_token? or halt '401'
      end
      def site_owner?(site_uuid)
        @site = Site.filter(:uuid => site_uuid, :owner_id => @user.id, :enabled => true).first || nil
        halt '404' if @site.nil?
      end
    end

    post '/signup' do
      @user = User.new(params.merge({ "site_id" => 1, "email" => params[:username] }))
      @user.save
      flash[:info] = "Please check your inbox for a confirmation email."
    end

    get '/confirm/:token/?' do
      @user = User.filter(:confirm_token => params[:token], :site_id => 1, :enabled => true, :confirmed => false).first
      if @user
        @user.confirm
        @user.save
        #flash[:success] = "Your email has been confirmed. You may now login."
      else
        #flash[:info] = "We were unable to confirm your email.<br />Please check your confirmation link for accuracy."
      end
    end

    post '/confirm' do
      @user = User.filter(:username => params[:username], :site_id => 1).first
      if @user
        if @user.confirmed?
          #flash[:info] = "This user has already been confirmed. Please login at any time."
        else
          @user.resend_confirmation
          #flash[:info] = "Please check your inbox for a new confirmation email."
        end
      else
        #flash[:error] = "Username not found. Please try again."
      end
    end

    get '/profile/?' do
      @user.to_json
    end

    put '/profile' do
      if ((! params[:password1].empty?) || (! params[:password2].empty?))
        if ((params[:password1] == params[:password2]) and (! params[:password1].empty?))
          @user.update_password(params[:password1])
        else
          #flash[:error] = "Those passwords don't match. Please try again."
        end
      end
      %w( password1 password2 ).each {|p| params.delete(p)}
      @user.update(params)
      @user.save
      #flash[:success] = "Your profile has been updated."
    end

    post '/sites/add' do
      @site = Site.new(:name => params[:name], :owner_id => @user.id).save
      #flash[:success] = "Site created!"
    end

    get '/sites/?' do
      @sites.to_json
    end

    get '/sites/:uuid/?' do
      @site = Site.filter(:uuid => params[:uuid], :owner_id => @user.id, :enabled => true).first || nil
      if !@site.nil?
        @site.to_json
      else
        #flash[:error] = "Site not found."
      end
    end

    delete '/sites/:uuid/?' do
      @site = Site.filter(:uuid => params[:uuid], :owner_id => @user.id, :enabled => true).first || nil
      if !@site.nil?
        @site.destroy
        #flash[:info] = "Site destroyed!"
      else
        #flash[:error] = "Site not found."
      end
    end

    post '/sites/:uuid/users/add' do
      params.delete("uuid")
      @site_user = User.new(params.merge({ "site_id" => @site.id, "email" => params[:username], "confirmed" => true }))
      @site_user.save
      @site_user.to_json
    end

    get '/sites/:uuid/users/?' do
      @site_users = User.from(:users, :sites).where(:users__site_id => :sites__id, :sites__uuid => params[:uuid], :users__enabled => true).select("users.*".lit, :sites__name.as(:site), :sites__uuid.as(:site_uuid)).order(:id).all
      if !@site_users.empty?
        @site_users.to_json
      else
        #flash[:info] = "No users found." if @users.empty?
      end
    end

    get '/sites/:uuid/users/:id/?' do
      @site_user = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@site_user.nil?
        @site_user.to_json
      else
        #flash[:error] = "User not found."
      end
    end

    put '/sites/:uuid/users/:id' do
      @site_user = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@site_user.nil?
        if ((! params[:password1].empty?) || (! params[:password2].empty?))
          if ((params[:password1] == params[:password2]) and (! params[:password1].empty?))
            @site_user.update_password(params[:password1])
          else
            #flash[:error] = "Those passwords don't match. Please try again."
          end
        end
        %w( password1 password2 uuid id ).each {|p| params.delete(p)}
        @site_user.update(params)
        @site_user.save
        @site_user.to_json
      else
        #flash[:error] = "User not found."
      end
    end

    delete '/sites/:uuid/users/:id' do
      @site_user = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@site_user.nil?
        @site_user.destroy
        #flash[:info] = "User destroyed!"
      else
        #flash[:error] = "User not found."
      end
    end

  end
end
