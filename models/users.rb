require "bcrypt"
require "uuid"
require "resque"
require "rest_client"

class User < Sequel::Model

  one_to_many :sites

  Resque.redis = ENV['REDISTOGO_URL']

  def before_create
    super
    self.created_at = Time.now
    self.updated_at = Time.now
    self.visited_at = Time.now
    self.password = encrypt_password(self.password)
    self.api_token = UUID.generate
    self.confirm_token = UUID.generate
  end

  def after_create
    Resque.enqueue(Email, self.id, :confirmation)
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
    Resque.enqueue(Email, self.id, :confirmation)
  end

  def confirm
    self.confirmed_at = Time.now
    self.updated_at = Time.now
    self.confirmed = true
    self.enabled = true
  end
end

module Email
  extend self
  @queue = :outbound

  def send_confirmation_to(user)
    RestClient.post ENV['MAILGUN_API_URL'] + "/messages",
                    :from    => "signup@vellup.com",
                    :to      => "#{user.firstname} #{user.lastname} <#{user.email}>",
                    :subject => "Vellup Confirmation",
                    :text    => "Click the following link to complete your registration:\n" +
                                "http://127.0.0.1:4567/users/#{user.username}/confirm/#{user.confirm_token}"
  end

  def perform(id, action)
    user = User.filter(:id => id).first
    send_confirmation_to(user) if (action == "confirmation")
  end
end

