
class Site < Sequel::Model

  many_to_one :users

  def before_create
    super
    self.uuid = UUID.generate(format = :compact)
    self.created_at = Time.now
    self.updated_at = Time.now
    self.visited_at = Time.now
    self.enabled = true
  end

  def after_create
  end

  def before_update
    super
    self.updated_at = Time.now
    self.visited_at = Time.now
  end

  def after_update
  end

  def before_destroy
  end

  def after_destroy
  end

  def enabled?
    self.enabled
  end

  def destroy
    self.enabled = false
    self.save
  end
end

