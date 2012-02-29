
class Sequel::Model
  def validates_json_schema(input)
    errors.add(input, 'is an invalid JSON schema') unless Schema.is_valid?(input)
  end
end

class Site < Sequel::Model

  many_to_one :users

  plugin :boolean_readers
  plugin :validation_helpers

  def before_validation
    super
    self.schema = '{}' if self.schema.empty?
  end

  def validate
    super
    validates_presence :name, :message => 'is required'
    validates_length_range 2..50, :name, :message => 'length must be between 2 and 50 characters'
    validates_json_schema self.schema unless self.schema.nil?
  end

  def before_create
    super
    self.uuid = UUID.generate(format = :compact)
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

  def destroy
    self.enabled = false
    self.save
  end

  def really_destroy
    self.delete
  end
end

