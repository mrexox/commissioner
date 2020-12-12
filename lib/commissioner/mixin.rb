# frozen_string_literal: true

module Commissioner
  module Mixin
    Order = ->(*order) { @@order = order }

    @@order = %i[
      commission
      exchange
      exchange_commission
    ]

    def calculate(params)
      Calculator.new(params, config: Commissioner.config, order: @@order).calculate
    end
  end
end
