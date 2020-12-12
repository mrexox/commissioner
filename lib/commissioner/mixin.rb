module Commissioner
  module Mixin
    # TODO: Allow configuring order of operations
    Order = ->(*order) { @@order = order }

    @@order = [
      :commission,
      :exchange,
      :exchange_commission
    ]

    def calculate(params)
      Calculator.new(params, config: Commissioner.config, order: @@order).calculate
    end
  end
end
