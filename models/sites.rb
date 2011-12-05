
class Site < Sequel::Model

  many_to_one :users

  def before_create
    super
    self.created_at = Time.now
    self.updated_at = Time.now
    self.visited_at = Time.now
    self.enabled = true
  end

  def before_update
    super
    self.updated_at = Time.now
    self.visited_at = Time.now
  end
end

