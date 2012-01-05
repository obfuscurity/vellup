
require 'json'
require 'json-schema'

module Schema
  extend self

  def is_valid_json?(input)
    begin JSON.parse(input)
      return true
    rescue Exception => e
      return false
    end
  end
  def is_valid?(input)
    begin JSON::Validator.validate!(input, nil, :validate_schema => true)
      return true
    rescue Exception => e
      return false
    end
  end
  def validates?(input, schema)
    begin JSON::Validator.validate!(schema.to_json, input.to_json, :validate_schema => true)
      return true
    rescue Exception => e
      return false
    end
  end
end
