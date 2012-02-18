
require 'bcrypt'
require 'resque'
require 'rest_client'
require 'rfc822'

class Sequel::Model
  def validates_password_complexity(input)
    errors.add(input, "Password must be at least 4 chars long") unless input.length >= 3
  end
  def validates_email(input)
    errors.add(input, "Invalid format, see RFC822") unless input.is_email?
  end
  #def validates_custom_data(input)
  #  errors.add(input, "User data incompatible with JSON Schema") unless Schema.user_is_valid?(input)
  #end
end

class User < Sequel::Model

  one_to_many :sites

  plugin :boolean_readers
  plugin :validation_helpers

  Resque.redis = ENV['REDISTOGO_URL']

  def validate
    super
    validates_presence :username
    validates_presence :password
    validates_length_range 2..60, :username
    validates_unique :username
    validates_password_complexity self.password
    validates_email self.username
    validates_email self.email
    #validates_custom_data :custom
  end

  def before_create
    super
    self.enabled = true
    self.created_at = Time.now
    self.updated_at = Time.now
    self.confirmed_at = Time.now if (self.confirmed == true)
    self.password = encrypt_password(self.password)
    self.api_token = UUID.generate
    self.confirm_token = UUID.generate
  end

  def after_create
  end

  def before_update
    super
    self.updated_at = Time.now
  end

  def after_update
  end

  def before_destroy
  end

  def after_destroy
  end

  def destroy
    self.enabled = false
    self.save
  end

  def really_destroy
    self.delete
  end

  def minimal_user_data
    data = {}
    data[:email] = self.email
    data[:confirm_token] = self.confirm_token
    data
  end

  def encrypt_password(string)
    BCrypt::Password.create(string, :cost => 10)
  end

  def self.authenticate(args)
    username = args[:username]
    challenge = args[:password]
    site = args[:site]
    user = filter(:username => :$u, :site_id => :$s, :confirmed => true, :enabled => true).call(:first, :u => username, :s => site) || nil
    if user.nil?
      return false
    else
      if BCrypt::Password.new(user[:password]) == challenge
        user.authenticated_at = Time.now
        user.save
        return user
      else
        return false
      end
    end
  end

  def send_confirmation_email
    Resque.enqueue(Email, minimal_user_data, :confirmation)
  end

  def send_welcome_email
    Resque.enqueue(Email, minimal_user_data, :welcome)
  end

  def confirm
    self.confirmed = true
    self.confirmed_at = Time.now
    self.updated_at = Time.now
  end

  def send_password_change_request_email
    self.confirm_token = UUID.generate
    self.save
    Resque.enqueue(Email, minimal_user_data, :resetpassword)
  end

  def update_password(string)
    self.password = encrypt_password(string)
    # destroy the old token
    self.confirm_token = UUID.generate
    self.save
  end

  def reset_api_token
    self.api_token = UUID.generate
    self.save
  end
end

module Email
  extend self
  @queue = :outbound

  def send_email_to(user, subject, message)
    RestClient.post ENV['MAILGUN_API_URL'] + '/messages',
                    :from    => 'support@vellup.com',
                    :to      => user['email'],
                    :subject => subject,
                    :text    => message
  end

  def perform(user, action)
    subject = message = ''
    base_url = ENV['APP_URL'] || 'http://127.0.0.1:4567'
    if user
      if (action == 'confirmation')
        subject = 'Vellup Confirmation'
        message = "Click the following link to complete your registration:\n" +
                  "#{base_url}/confirm/#{user['confirm_token']}"
      elsif (action == 'welcome')
        subject = 'Welcome to Vellup'
        message = "You are now registered for Vellup! Get started here:\n" +
                     "#{base_url}/login"
      elsif (action == 'resetpassword')
        subject = 'Vellup Password Change'
        message = "Click the following link to change your password:\n" +
                  "#{base_url}/reset-password/#{user['confirm_token']}"
      end
    end
    send_email_to(user, subject, message)
  end
end

