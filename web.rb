require 'sinatra'
require 'rack-flash'
require 'sinatra/redirect_with_flash'
require 'rfc822'
require 'json'
require 'haml'
require 'newrelic_rpm'

require './models/all'

module Vellup
  class Web < Sinatra::Base

    use Rack::Flash, :sweep => true

    configure do
      enable :logging
      enable :method_override
      enable :sessions
      disable :raise_errors
      disable :show_exceptions
      set :session_secret, 'o28fKzX7qP0fr7C'
      set :haml, :format => :html5
      set :port, ENV['PORT'] || 4567
    end

    before do
      if has_web_session?
        @user = User.filter(:username => :$u, :site_id => :$s).call(:first, :u => session[:user], :s => 1)
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
      error = e.message.split(',').first
      flash[:error] = error
      # XXX need to send them... somewhere
      halt 400
    end

    helpers do
      def has_web_session?
        !session[:user].nil?
      end
      def check_for_existing_session
        if has_web_session?
          flash[:warning] = "Hey, you're already logged in. Here's your user profile instead."
          redirect '/profile'
        end
      end
      def start_web_session
        session[:user] = @user.username
      end
      def expire_web_session
        session.clear
        @user = nil
      end
      def authenticated?
        redirect '/login' unless has_web_session?
      end
      def site_owner?(site_uuid)
        @site = Site.filter(:uuid => :$u, :owner_id => @user.id, :enabled => true).call(:first, :u => site_uuid)
        redirect '/not_found' if @site.nil?
      end
      def has_at_least_one_site?
        if @sites.empty?
          flash[:info] = 'Please add your first Site.'
          redirect '/sites/add'
        end
      end
    end

    get '/api' do
      haml :api
    end

    get '/login/?' do
      check_for_existing_session
      haml :login
    end

    post '/login' do
      check_for_existing_session
      @user = User.authenticate(params.merge({ :site => 1 }))
      if @user
        start_web_session
        redirect '/sites'
      else
        flash[:info] = 'Username or Password Invalid, Please Try Again'
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
      check_for_existing_session
      haml :'users/add', :locals => { :view => 'signup' }
    end

    post '/signup' do
      check_for_existing_session
      if !User.username_collision?({ :username => params[:username], :site_id => 1 })
        if params[:username].is_email?
          # XXX Need to implement model-level prepared statements for escaping user input
          @user = User.new(params.merge({ 'site_id' => 1, 'email' => params[:username] })).save
          @user.send_confirmation_email
          flash[:info] = 'Please check your inbox for a confirmation email.'
          redirect '/login'
        else
          flash[:error] = 'Username must be a valid email address ( per <a href="http://www.ietf.org/rfc/rfc2822.txt">RFC2822</a> ). Please try again.'
          redirect '/signup'
        end
      else
        flash[:error] = 'This username is taken, please choose another.'
        redirect '/signup'
      end
    end

    get '/confirm/:token/?' do
      check_for_existing_session
      @user = User.filter(:confirm_token => :$t, :site_id => 1, :enabled => true, :confirmed => false).call(:first, :t => params[:token])
      if @user
        @user.confirm
        @user.save
        @user.send_welcome_email
        flash[:success] = 'Your email has been confirmed. You may now login.'
        redirect '/login'
      else
        flash[:info] = 'We were unable to confirm your email.<br />Please check your confirmation link for accuracy.'
        redirect '/login'
      end
    end

    get '/confirm/?' do
      check_for_existing_session
      haml :'users/confirm'
    end

    post '/confirm' do
      check_for_existing_session
      @user = User.filter(:username => :$u, :site_id => 1).call(:first, :u => params[:username])
      if @user
        if @user.confirmed?
          flash[:info] = 'This user has already been confirmed. Please login at any time.'
          redirect '/login'
        else
          @user.send_confirmation_email
          flash[:info] = 'Please check your inbox for a new confirmation email.'
          redirect '/login'
        end
      else
        flash[:error] = 'Username not found. Please try again.'
        haml :'users/confirm'
      end
    end

    get '/reset-password/?' do
      check_for_existing_session
      haml :'users/reset_password', :locals => { :show_reset_form => false }
    end

    post '/reset-password' do
      check_for_existing_session
      @user = User.filter(:username => :$u, :site_id => 1).call(:first, :u => params[:username])
      if @user
        if @user.confirmed?
          @user.send_password_change_request_email
          flash[:info] = 'Please check your inbox for directions to reset your password.'
          redirect '/login'
        else
          flash[:error] = "Your account hasn't been confirmed yet. Do you need a new confirmation email instead?"
          redirect '/confirm'
        end
      else
        flash[:error] = 'Username not found. Please try again.'
        haml :'users/reset_password'
      end
    end

    get '/reset-password/:token/?' do
      check_for_existing_session
      @user = User.filter(:confirm_token => :$t, :site_id => 1).call(:first, :t => params[:token])
      if @user
        haml :'users/reset_password', :locals => { :show_reset_form => true }
      else
        flash[:error] = "I don't recognize that token. Mind if we try again?"
        redirect '/reset-password'
      end
    end

    post '/reset-password/:token/?' do
      check_for_existing_session
      @user = User.filter(:confirm_token => :$t, :site_id => 1).call(:first, :t => params[:token])
      if @user
        if ((params[:password1] == params[:password2]) and (!params[:password1].empty?))
          @user.update_password(params[:password1])
          flash[:success] = 'Your password has been successfully changed.'
          redirect '/login'
        else
          flash[:error] = "Those passwords don't match. Please try again."
          haml :'users/reset_password', :locals => { :show_reset_form => true }
        end
      else
        flash[:error] = "I don't recognize that token. Mind if we try again?"
        redirect '/reset-password'
      end
    end

    get '/profile/?' do
      authenticated?
      preview = nil
      if !@user.values[:custom].nil?
        preview = JSON.pretty_generate(JSON.parse(@user.values[:custom]))
      end
      haml :'users/profile', :locals => { :profile => @user, :preview => preview, :site => nil }
    end

    put '/profile' do
      authenticated?
      tmp_params = {}; JSON.parse(params[:custom]).each {|k,v| tmp_params[k.to_sym] = v}
      if Schema.validates?(@user.values.merge(tmp_params), JSON.parse(Site[1].values[:schema]))
        if ((! params[:password1].empty?) || (! params[:password2].empty?))
          if ((params[:password1] == params[:password2]) and (! params[:password1].empty?))
            @user.update_password(params[:password1])
          else
            flash[:error] = "Those passwords don't match. Please try again."
            redirect '/profile'
          end
        end
        @user.update(:custom => params[:custom])
        @user.save
        flash[:success] = 'Your profile has been updated.'
        redirect '/profile'
      else
        flash[:error] = 'Invalid settings. Please try again.'
        redirect '/profile'
      end
    end

    post '/reset-token' do
      authenticated?
      @user.reset_api_token
      flash[:success] = 'Your API token has been reset.'
      redirect '/profile'
    end

    get '/sites/add/?' do
      authenticated?
      haml :'sites/add'
    end

    post '/sites/add' do
      authenticated?
      @site = Site.new(params.merge({ :schema => schema, :visited_at => Time.now, :owner_id => @user.id })).save
      flash[:success] = 'Site created!'
      redirect "/sites/#{@site.uuid}"
    end

    get '/sites/?' do
      authenticated?
      has_at_least_one_site?
      haml :'sites/list'
    end

    get '/sites/:uuid/?' do
      authenticated?
      site_owner?(params[:uuid])
      haml :'sites/profile', :locals => { :profile => @site.values, :schema => @site.schema }
    end

    put '/sites/:uuid' do
      authenticated?
      site_owner?(params[:uuid])
      params.delete('_method')
      @site.update(params.merge({ :schema => schema }))
      @site.save
      flash[:success] = 'Site updated.'
      redirect "/sites/#{@site.uuid}"
    end

    delete '/sites/:uuid/?' do
      authenticated?
      site_owner?(params[:uuid])
      @site.destroy
      flash[:info] = 'Site destroyed!'
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
      params.delete('uuid')
      @site_user = User.new(params.merge({ 'site_id' => @site.id, 'email' => params[:username], 'confirmed' => true })).save
      flash[:success] = 'User added.'
      redirect "/sites/#{@site.uuid}/users"
    end

    get '/sites/:uuid/users/?' do
      authenticated?
      site_owner?(params[:uuid])
      @users = User.select('users.*'.lit, :sites__name.as(:site), :sites__uuid.as(:site_uuid)).from(:users, :sites).where(:users__site_id => :sites__id, :sites__uuid => :$u, :users__enabled => true).order(:id).call(:all, :u => params[:uuid])
      flash[:info] = 'No users found.' if @users.empty?
      haml :'users/list', :locals => { :users => @users, :site => @site.name, :uuid => @site.uuid }
    end

    get '/sites/:uuid/users/:id/?' do
      authenticated?
      site_owner?(params[:uuid])
      @profile = User.filter(:id => :$i, :site_id => @site.id, :enabled => true).call(:first, :i => params[:id])
      if !@profile.nil?
        preview = JSON.pretty_generate(JSON.parse(@profile.values[:custom]))
        haml :'users/profile', :locals => { :profile => @profile, :preview => preview, :site => @site.name, :uuid => @site.uuid }
      else
        flash[:error] = 'User not found.'
        redirect "/sites/#{@site.uuid}/users"
      end
    end

    put '/sites/:uuid/users/:id' do
      authenticated?
      site_owner?(params[:uuid])
      @site_user = User.filter(:id => :$i, :site_id => @site.id, :enabled => true).call(:first, :i => params[:id])
      if !@site_user.nil?
        if ((! params[:password1].empty?) || (! params[:password2].empty?))
          if ((params[:password1] == params[:password2]) and (! params[:password1].empty?))
            @site_user.update_password(params[:password1])
          else
            flash[:error] = "Those passwords don't match. Please try again."
            redirect "/sites/#{@site.uuid}/users/#{@site_user.id}"
          end
        end
        @site_user.update(:custom => params[:custom])
        @site_user.save
        flash[:success] = "The user's profile has been updated."
        redirect "/sites/#{@site.uuid}/users/#{@site_user.id}"
      else
        flash[:error] = 'User not found.'
        redirect "/sites/#{@site.uuid}/users"
      end
    end

    delete '/sites/:uuid/users/:id' do
      authenticated?
      site_owner?(params[:uuid])
      @site_user = User.filter(:id => :$i, :site_id => @site.id, :enabled => true).call(:first, :i => params[:id])
      if !@site_user.nil?
        @site_user.destroy
        flash[:info] = 'User destroyed!'
        redirect "/sites/#{@site.uuid}/users"
      else
        flash[:error] = 'User not found.'
        redirect "/sites/#{@site.uuid}/users"
      end
    end
  end
end
