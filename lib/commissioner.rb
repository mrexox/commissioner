require 'commissioner/version'
require 'commissioner/calculator'
require 'commissioner/mixin'
require 'dry-configurable'

module Commissioner
  extend Dry::Configurable

  # A lambda that accepts from_currency, to_currency, amount
  setting :exchanger, reader: true # arity = 3
  setting :rounding_mode, :half_up # possible values: :up, :down, :half_up, :half_even

  def self.calculate(params)
    Calculator.new(params, config: self.config).calculate
  end
end
