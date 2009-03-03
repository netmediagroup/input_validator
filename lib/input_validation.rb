class << ActiveRecord::Base
  def input_validation(options={})
    input_validator = InputValidator.new(options)
    before_validation input_validator
    validate input_validator
  end
end