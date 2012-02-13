
class Sequel::Model
  #def validates_json_schema(input)
  #  errors.add(input, "Invalid JSON Schema") unless Schema.is_valid?(input)
  #end
end

class Site < Sequel::Model

  many_to_one :users

  plugin :boolean_readers
  plugin :validation_helpers

  def validate
    super
    validates_presence :name
    validates_length_range 2..50, :name
    #validates_json_schema :schema
  end

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

  def destroy
    self.enabled = false
    self.save
  end

  def really_destroy
    self.delete
  end
end

