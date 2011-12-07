require "sinatra"
require "newrelic_rpm"
require "rack-flash"
require "sinatra/redirect_with_flash"
require "haml"

require "./models/all"

module Vellup
  class Application < Sinatra::Base

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
        @user = User.filter(:username => session[:user]).first
        @current_site = Site.filter(:owner_id => @user.id).order_by(:visited_at.desc).first || nil
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
      def site_owner?(site_id)
        Site.filter(:id => site_id, :owner_id => @user.id).first ? true : false
      end
      def has_at_least_one_site?
        if @current_site.nil?
          flash[:info] = "Please add your first Site."
          redirect '/sites/add'
        end
      end
    end

    get '/login/?' do
      haml :login
    end

    post '/login' do
      @user = User.authenticate(params[:username], params[:password]) || nil
      if @user
        start_web_session
        redirect '/sites'
      else
        flash[:info] = "Username or Password Invalid, Please Try Again"
        redirect '/login'
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
      haml :signup
    end

    post '/signup' do
      @user = User.new(params)
      @user.email_is_username = false
      @user.save
      flash[:info] = "Please check your inbox for a confirmation email."
      redirect '/login'
    end

    get '/confirm/:token/?' do
      @user = User.filter(:confirm_token => params[:token], :enabled => true, :confirmed => false).first || nil
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

    get '/confirm/?' do
      if has_session?
        if session[:user] == params[:id]
          flash[:info] = "Congratulations, this user has already been confirmed!"
          redirect '/'
        else
          flash[:info] = "Do you want to resend confirmation for a different user?<br />If so, please logout and try again."
          redirect '/'
        end
      else
        haml :'users/confirm'
      end
    end

    post '/confirm' do
      @user = User.filter(:username => params[:id]).first || nil
      if @user
        if @user.confirmed == false
          @user.resend_confirmation
          flash[:info] = "Please check your inbox for a new confirmation email."
          redirect '/login'
        else
          flash[:info] = "Congratulations, this user has already been confirmed!<br />Please login at any time."
          redirect '/login'
        end
      else
        flash[:info] = "Username not found. Please try again."
        redirect '/login'
      end
    end

    get '/profile/?' do
      authenticated?
      if @user.username == params[:id]
        haml :'users/profile', :locals => { :profile => @user }
      else
        redirect '/contemplative_robot'
      end
    end

    put '/profile' do
      authenticated?
      if @user.username == params[:id]
        %w( _method id submit ).each {|v| params.delete(v) }
        @user.update(params).save
        flash[:info] = "Your profile has been updated."
        haml :'users/profile', :locals => { :profile => @user }
      else
        redirect '/contemplative_robot'
      end
    end

    get '/sites/add/?' do
      authenticated?
      haml :'sites/add'
    end

    post '/sites/add' do
      authenticated?
      @site = Site.new(:name => params[:name], :owner_id => @user.id).save
      flash[:success] = "Site created!"
      redirect "/sites/#{@site.name}"
    end

    get '/sites/?' do
      authenticated?
      has_at_least_one_site?
      @sites = Site.filter(:owner_id => @user.id, :enabled => true)
      haml :'sites/list'
    end

    get '/sites/:name/?' do
      authenticated?
      @profile = Site.filter(:name => params[:name], :owner_id => @user.id, :enabled => true).first.values
      haml :'sites/profile', :locals => { :profile => @profile }
    end

    delete '/sites/:name' do
      authenticated?
      Site.filter(:name => params[:name], :owner_id => @user.id).destroy
      flash[:info] = "Site destroyed!"
      redirect "/sites"
    end

    post '/sites/:site/users/add' do
      authenticated?
      site_owner?
      "new user submission"
    end

    get '/sites/:site/users/?' do
      authenticated?
      site_owner?
      haml :'users/list', :locals => { :users => @users, :site => params[:site] }
    end

    get '/sites/:site/users/:id/?' do
      authenticated?
      site_owner?
      @profile = User.filter(:id => params[:id]).first
      haml :'users/profile', :locals => { :profile => @profile }
    end

    put '/sites/:site/users/:id' do
      authenticated?
      site_owner?
      "user profile submission"
    end

    delete '/sites/:site/users/:id' do
      authenticated?
      site_owner?
      "user delete"
    end

  end
end
