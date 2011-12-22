
require "sinatra"
require "rack-flash"
require "sinatra/redirect_with_flash"
require "haml"
require "newrelic_rpm"

require "./models/all"

module Vellup
  class Web < Sinatra::Base

    use Rack::Flash, :sweep => true

    configure do
      enable :logging
      enable :method_override
      enable :sessions
      set :session_secret, 'o28fKzX7qP0fr7C'
      set :haml, :format => :html5
    end

    before do
      if has_web_session?
        @user = User.filter(:username => session[:user], :site_id => 1).first
        @sites = Site.filter(:owner_id => @user.id, :enabled => true).order_by(:created_at.asc).all
      else
        @next_url = params[:next_url] || request.path
      end
    end

    after do
      if @next_url
        flash[:next_url] = @next_url
      end
    end

    not_found do
      haml :not_found
    end

    error do
      e = request.env['sinatra.error']
      puts e.to_s
      puts e.backtrace.join("\n")
      "Application error"
    end

    helpers do
      def has_web_session?
        session[:user] ? true : false
      end
      def start_web_session
        session[:user] = @user.username
      end
      def expire_web_session
        session.clear
        @user = nil
      end
      def authenticated?
        has_web_session? or redirect '/login'
      end
      def site_owner?(site_uuid)
        @site = Site.filter(:uuid => site_uuid, :owner_id => @user.id, :enabled => true).first || nil
        redirect '/not_found' if @site.nil?
      end
      def has_at_least_one_site?
        if @sites.empty?
          flash[:info] = "Please add your first Site."
          redirect '/sites/add'
        end
      end
    end

    get '/login/?' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        haml :login
      end
    end

    post '/login' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        @user = User.authenticate(params.merge({ :site => 1 }))
        if @user
          start_web_session
          redirect '/sites'
        else
          flash[:info] = "Username or Password Invalid, Please Try Again"
          redirect '/login'
        end
      end
    end

    get '/logout/?' do
      expire_web_session
      haml :index
    end

    get '/' do
      haml :index
    end

    get '/signup/?' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        haml :'users/add', :locals => { :view => "signup" }
      end
    end

    post '/signup' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        @user = User.new(params.merge({ "site_id" => 1, "email" => params[:username] }))
        @user.save
        flash[:info] = "Please check your inbox for a confirmation email."
        redirect '/login'
      end
    end

    get '/confirm/:token/?' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        @user = User.filter(:confirm_token => params[:token], :site_id => 1, :enabled => true, :confirmed => false).first
        if @user
          @user.confirm
          @user.save
          flash[:success] = "Your email has been confirmed. You may now login."
          redirect '/login'
        else
          flash[:info] = "We were unable to confirm your email.<br />Please check your confirmation link for accuracy."
          redirect '/login'
        end
      end
    end

    get '/confirm/?' do
      if has_web_session?
        flash[:info] = "Do you want to resend confirmation for a different user? If so, please logout and try again."
        redirect '/profile'
      else
        haml :'users/confirm'
      end
    end

    post '/confirm' do
      if has_web_session?
        flash[:info] = "Do you want to resend confirmation for a different user? If so, please logout and try again."
        redirect '/profile'
      else
        @user = User.filter(:username => params[:username], :site_id => 1).first
        if @user
          if @user.confirmed?
            flash[:info] = "This user has already been confirmed. Please login at any time."
            redirect '/login'
          else
            @user.resend_confirmation
            flash[:info] = "Please check your inbox for a new confirmation email."
            redirect '/login'
          end
        else
          flash[:error] = "Username not found. Please try again."
          haml :'users/confirm'
        end
      end
    end

    get '/reset-password/?' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        haml :'users/reset_password', :locals => { :show_reset_form => false }
      end
    end

    post '/reset-password' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        @user = User.filter(:username => params[:username], :site_id => 1).first
        if @user
          if @user.confirmed?
            @user.send_password_change_request
            flash[:info] = "Please check your inbox for directions to reset your password."
            redirect '/login'
          else
            flash[:error] = "Your account hasn't been confirmed yet. Do you need a new confirmation email instead?"
            redirect '/confirm'
          end
        else
          flash[:error] = "Username not found. Please try again."
          haml :'users/reset_password'
        end
      end
    end

    get '/reset-password/:token/?' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        @user = User.filter(:confirm_token => params[:token], :site_id => 1).first
        if @user
          haml :'users/reset_password', :locals => { :show_reset_form => true }
        else
          flash[:error] = "I don't recognize that token. Mind if we try again?"
          redirect '/reset-password'
        end
      end
    end

    post '/reset-password/:token/?' do
      if has_web_session?
        flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
        redirect '/profile'
      else
        @user = User.filter(:confirm_token => params[:token], :site_id => 1).first
        if @user
          p @user
          if ((params[:password1] == params[:password2]) and (!params[:password1].empty?))
            p "HERE 1"
            @user.update_password(params[:password1])
            flash[:success] = "Your password has been successfully changed."
            redirect '/login'
          else
            p "HERE 2"
            flash[:error] = "Those passwords don't match. Please try again."
            haml :'users/reset_password', :locals => { :show_reset_form => true }
          end
        else
          flash[:error] = "I don't recognize that token. Mind if we try again?"
          redirect '/reset-password'
        end
      end
    end

    get '/profile/?' do
      authenticated?
      haml :'users/profile', :locals => { :profile => @user, :site => nil }
    end

    put '/profile' do
      authenticated?
      if ((! params[:password1].empty?) || (! params[:password2].empty?))
        if ((params[:password1] == params[:password2]) and (! params[:password1].empty?))
          @user.update_password(params[:password1])
        else
          flash[:error] = "Those passwords don't match. Please try again."
          redirect '/profile'
        end
      end
      %w( _method password1 password2 ).each {|p| params.delete(p)}
      @user.update(params)
      @user.save
      flash[:success] = "Your profile has been updated."
      redirect '/profile'
    end

    get '/sites/add/?' do
      authenticated?
      haml :'sites/add'
    end

    post '/sites/add' do
      authenticated?
      @site = Site.new(:name => params[:name], :owner_id => @user.id).save
      flash[:success] = "Site created!"
      redirect "/sites/#{@site.uuid}"
    end

    get '/sites/?' do
      authenticated?
      has_at_least_one_site?
      haml :'sites/list'
    end

    get '/sites/:uuid/?' do
      authenticated?
      @site = Site.filter(:uuid => params[:uuid], :owner_id => @user.id, :enabled => true).first || nil
      if !@site.nil?
        haml :'sites/profile', :locals => { :profile => @site.values }
      else
        flash[:error] = "Site not found."
        redirect '/sites'
      end
    end

    delete '/sites/:uuid/?' do
      authenticated?
      @site = Site.filter(:uuid => params[:uuid], :owner_id => @user.id, :enabled => true).first || nil
      if !@site.nil?
        @site.destroy
        flash[:info] = "Site destroyed!"
      else
        flash[:error] = "Site not found."
      end
      redirect '/sites'
    end

    get '/sites/:uuid/users/add' do
      authenticated?
      site_owner?(params[:uuid])
      haml :'users/add', :locals => { :view => true, :site => @site.name, :uuid => @site.uuid }
    end

    post '/sites/:uuid/users/add' do
      authenticated?
      site_owner?(params[:uuid])
      params.delete("uuid")
      @site_user = User.new(params.merge({ "site_id" => @site.id, "email" => params[:username], "confirmed" => true }))
      @site_user.save
      flash[:success] = "User added."
      redirect "/sites/#{@site.uuid}/users"
    end

    get '/sites/:uuid/users/?' do
      authenticated?
      site_owner?(params[:uuid])
      @users = User.from(:users, :sites).where(:users__site_id => :sites__id, :sites__uuid => params[:uuid], :users__enabled => true).select("users.*".lit, :sites__name.as(:site), :sites__uuid.as(:site_uuid)).order(:id).all
      flash[:info] = "No users found." if @users.empty?
      haml :'users/list', :locals => { :users => @users, :site => @site.name, :uuid => @site.uuid }
    end

    get '/sites/:uuid/users/:id/?' do
      authenticated?
      site_owner?(params[:uuid])
      @profile = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@profile.nil?
        haml :'users/profile', :locals => { :profile => @profile, :site => @site.name, :uuid => @site.uuid }
      else
        flash[:error] = "User not found."
        redirect "/sites/#{@site.uuid}/users"
      end
    end

    put '/sites/:uuid/users/:id' do
      authenticated?
      site_owner?(params[:uuid])
      @site_user = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@site_user.nil?
        if ((! params[:password1].empty?) || (! params[:password2].empty?))
          if ((params[:password1] == params[:password2]) and (! params[:password1].empty?))
            @site_user.update_password(params[:password1])
          else
            flash[:error] = "Those passwords don't match. Please try again."
            redirect "/sites/#{@site.uuid}/users/#{@site_user.id}"
          end
        end
        %w( _method password1 password2 uuid id ).each {|p| params.delete(p)}
        @site_user.update(params)
        @site_user.save
        flash[:success] = "The user's profile has been updated."
        redirect "/sites/#{@site.uuid}/users/#{@site_user.id}"
      else
        flash[:error] = "User not found."
        redirect "/sites/#{@site.uuid}/users"
      end
    end

    delete '/sites/:uuid/users/:id' do
      authenticated?
      site_owner?(params[:uuid])
      @site_user = User.filter(:id => params[:id], :site_id => @site.id, :enabled => true).first || nil
      if !@site_user.nil?
        @site_user.destroy
        flash[:info] = "User destroyed!"
        redirect "/sites/#{@site.uuid}/users"
      else
        flash[:error] = "User not found."
        redirect "/sites/#{@site.uuid}/users"
      end
    end

  end
end
