# frozen_string_literal: true

require 'commissioner/version'
require 'commissioner/calculator'
require 'commissioner/mixin'
require 'dry-configurable'

module Commissioner
  extend Dry::Configurable

  # A lambda that accepts from_currency, to_currency, amount
  setting :exchanger, ->(_from, _to, amount) { amount }, reader: true
  # Possible values: :up, :down, :half_up, :half_even
  setting :rounding_mode, :half_up

  def self.calculate(params)
    Calculator.new(params, config: config).calculate
  end
end
