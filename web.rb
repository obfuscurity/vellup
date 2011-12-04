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
        @current_site.nil? and redirect '/sites/add'
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
        flash[:notice] = "Username or Password Invalid, Please Try Again"
        redirect '/login'
      end
    end

    get '/logout/?' do
      expire_web_session
      haml :login
    end

    get '/' do
      haml :index
    end

    get '/signup/?' do
      redirect '/sites/vellup/users/add'
    end

    get '/users/:id/?' do
      redirect "/sites/vellup/users/#{params[:id]}"
    end

    post '/users/add' do
      params.delete("submit")
      @user = User.new(params)
      @user.save
      flash[:notice] = "Please check your inbox for a confirmation email."
      redirect '/login'
    end

    get '/users/:id/confirm/:token/?' do
      @user = User.filter(:username => params[:id], :confirm_token => params[:token]).first || nil
      if @user
        @user.confirm
        @user.save
        flash[:notice] = "Your email has been confirmed. You may now login."
        redirect '/login'
      else
        flash[:notice] = "We were unable to confirm your email.<br />Please check your confirmation link for accuracy."
        redirect '/login'
      end
    end

    get '/users/:id/confirm/?' do
      if has_session?
        if session[:user] == params[:id]
          flash[:notice] = "Congratulations, this user has already been confirmed!"
          redirect '/'
        else
          flash[:notice] = "Do you want to resend confirmation for a different user?<br />If so, please logout and try again."
          redirect '/'
        end
      else
        haml :'users/confirm'
      end
    end

    post '/users/:id/confirm' do
      @user = User.filter(:username => params[:id]).first || nil
      if @user
        if @user[:confirmed] == false
          @user.resend_confirmation
          flash[:notice] = "Please check your inbox for a new confirmation email."
          redirect '/login'
        else
          flash[:notice] = "Congratulations, this user has already been confirmed!<br />Please login at any time."
          redirect '/login'
        end
      else
        flash[:notice] = "Username not found. Please try again."
        redirect '/login'
      end
    end

    get '/users/:id/?' do
      authenticated?
      if @user[:username] == params[:id]
        haml :'users/profile', :locals => { :profile => @user }
      else
        redirect '/contemplative_robot'
      end
    end

    put '/users/:id' do
      authenticated?
      if @user[:username] == params[:id]
        %w( _method id submit ).each {|v| params.delete(v) }
        @user.update(params)
        @user.save
        flash[:notice] = "Your profile has been updated."
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
      "new site submission"
    end

    get '/sites/?' do
      authenticated?
      has_at_least_one_site?
      @sites = Site.filter(:owner_id => @user[:id])
      haml :'sites/list'
    end

    get '/sites/:id/?' do
      authenticated?
      @profile = Site.filter(:name => params[:id]).first.values
      haml :'sites/profile', :locals => { :profile => @profile }
    end

    put '/sites/:id' do
      authenticated?
      "site profile submission"
    end

    delete '/sites/:id' do
      authenticated?
      "site delete"
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
      @profile = user.filter(:id => params[:id]).first.values
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
