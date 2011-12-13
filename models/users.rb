require "bcrypt"
require "uuid"
require "resque"
require "rest_client"

class User < Sequel::Model

  one_to_many :sites

  Resque.redis = ENV['REDISTOGO_URL']

  def before_create
    super
    self.email = self.username if (self.email_is_username)
    self.enabled = true
    self.created_at = Time.now
    self.updated_at = Time.now
    self.visited_at = Time.now
    self.password = encrypt_password(self.password)
    self.api_token = UUID.generate
    self.confirm_token = UUID.generate
  end

  def after_create
    Resque.enqueue(Email, minimal_user_data, :confirmation)
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

  def minimal_user_data
    data = {}
    data[:firstname] = self.firstname
    data[:lastname] = self.lastname
    data[:email] = self.email
    data[:confirm_token] = self.confirm_token
    data
  end

  def encrypt_password(string)
    BCrypt::Password.create(string, :cost => 10)
  end

  def self.authenticate(username, challenge)
    user = filter(:username => username, :confirmed => true, :enabled => true).first
    if user.nil?
      return false
    else
      if BCrypt::Password.new(user[:password]) == challenge
        return user
      else
        return false
      end
    end
  end

  def resend_confirmation
    Resque.enqueue(Email, minimal_user_data, :confirmation)
  end

  def confirm
    self.confirmed = true
    self.confirmed_at = Time.now
    self.updated_at = Time.now
    Resque.enqueue(Email, minimal_user_data, :confirmed)
  end

  def confirmed?
    self.confirmed
  end

  def send_password_change_request
 puts "old token is #{self.confirm_token}"
    self.confirm_token = UUID.generate
 puts "new token is #{self.confirm_token}"
    Resque.enqueue(Email, minimal_user_data, :resetpassword)
  end

  def password=(string)
    self.password = encrypt_password(string)
  end
end

module Email
  extend self
  @queue = :outbound

  def send_email_to(user, subject, message)
    RestClient.post ENV['MAILGUN_API_URL'] + "/messages",
                    :from    => "support@vellup.com",
                    :to      => "#{user['firstname'].capitalize} #{user['lastname'].capitalize} <#{user['email']}>",
                    :subject => subject,
                    :text    => message
  end

  def perform(user, action)
    subject = message = ""
    if user
      if (action == "confirmation")
        subject = "Vellup Confirmation"
        message = "Click the following link to complete your registration:\n" +
                  "http://127.0.0.1:4567/confirm/#{user['confirm_token']}"
      elsif (action == "confirmed")
        subject = "Welcome to Vellup"
        message = "You are now registered for Vellup! Get started here:\n" +
                     "http://127.0.0.1:4567/login"
      elsif (action == "resetpassword")
        subject = "Vellup Password Change"
        message = "Click the following link to change your password:\n" +
                  "http://127.0.0.1:4567/reset-password/#{user['confirm_token']}"
      end
    end
    send_email_to(user, subject, message)
  end
end

