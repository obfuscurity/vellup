require "sinatra"
require "newrelic_rpm"
require "rack-flash"
#require "sinatra/redirect_with_flash"
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
      end
    end

    not_found do
      flash[:not_found] = true
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
      def account_owner?(account_id)
        Account.filter(:id => account_id, :owner_id => @user.id).first ? true : false
      end
    end

    get '/login/?' do
      haml :login
    end

    post '/login' do
      @user = User.authenticate(params[:username], params[:password]) || nil
      if @user
        start_web_session
        redirect '/accounts'
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
      redirect '/accounts/vellup/users/add'
    end

    get '/users/:id/?' do
      redirect "/accounts/vellup/users/#{params[:id]}"
    end

    get '/accounts/?' do
      authenticated?
      haml :'accounts/list'
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

    get '/accounts/add/?' do
      authenticated?
      haml :'accounts/add'
    end

    post '/accounts/add' do
      authenticated?
      "new account submission"
    end

    get '/accounts/?' do
      authenticated?
      has_at_least_one_account?
      @accounts = Account.filter(:owner_id => @user[:id])
      haml :'accounts/list'
    end

    get '/accounts/:id/?' do
      authenticated?
      @profile = Account.filter(:name => params[:id]).first.values
      haml :'accounts/profile', :locals => { :profile => @profile }
    end

    put '/accounts/:id' do
      authenticated?
      "account profile submission"
    end

    delete '/accounts/:id' do
      authenticated?
      "account delete"
    end

    post '/accounts/:account/users/add' do
      authenticated?
      account_owner?
      "new user submission"
    end

    get '/accounts/:account/users/?' do
      authenticated?
      account_owner?
      haml :'users/list', :locals => { :users => @users, :account => params[:account] }
    end

    get '/accounts/:account/users/:id/?' do
      authenticated?
      account_owner?
      @profile = user.filter(:id => params[:id]).first.values
      haml :'users/profile', :locals => { :profile => @profile }
    end

    put '/accounts/:account/users/:id' do
      authenticated?
      account_owner?
      "user profile submission"
    end

    delete '/accounts/:account/users/:id' do
      authenticated?
      account_owner?
      "user delete"
    end

  end
end
