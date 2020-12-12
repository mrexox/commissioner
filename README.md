# Commissioner Guy

[![Build Status](https://travis-ci.org/mrexox/commissioner.svg?branch=main)](https://travis-ci.org/mrexox/commissioner)
[![Gem Version](https://badge.fury.io/rb/commissioner-guy.svg)](https://badge.fury.io/rb/commissioner-guy)

Calculates charged and received amounts based on provided one. Calls your exchanger if needed. Applies commissions in order that you define.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'commissioner-guy', require: 'commissioner'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install commissioner-guy

## Usage

### First, configure the gem

```ruby
require 'commissioner'

Commissioner.configure do |config|
  # If you exchange money provider the lambda that receives
  #   from   - string
  #   to     - string
  #   amount - Money instance
  # 'amount' might be in 'from' or 'to' currency
  # Must return either just exchanged amount or [amount, exchanged_rate]
  config.exchanger = ->(from, to, amount) { ... }

  # When applying commission the amount might be rounded. This setting
  # defined the rounding mode. Available modes are:
  # - :up
  # - :down
  # - :half_up
  # - :half_even
  # See BigDecimal rounding modes for more
  config.rouding_mode = :up
end
```

### Explicit call

```ruby
calculation = Commissioner.calculate(
  charged_amount: 100,
  charged_currency: 'EUR',
  received_currency: 'USD',
  commission: 10, # %
  exchange_commission: 15 # %
)

calculation.charged_amount # #<Money fractional:10000 currency:EUR>
calculation.received_amount # #<Money fractional:7650 currency:USD>
calculation.fee # #<Money fractional:1000 currency:EUR>
calculation.exchange_fee # <Money fractional:1350 currency:USD>
calculation.exchange_rate # 1 (only if config.exchanger returns it)
```

### As a mixin

```ruby
class MyCalculator
  include Commissiner::Mixin

  def call(params)
    calculate(params)
  end
end
```

#### Specify order

You can specify in which order calculation will be applied. The steps are:

- exchange
- commission
- exchange_commission

`exchange` - calls exchanger if currencies of received and charged amounts differ
`commission` - applies typical commission operation
`exchange_commission` - applies commission for exchange (in charged currency if ordered before `exchange` or in received currency if ordered after `exchange`)

```ruby
class MyCalculator
  include Commissioner::Mixin

  # Default order is:
  # - :commission
  # - :exchange
  # - :exchange_commission

  Order[
    :commission,
    :exchange_commission,
    :exchange
  ]
end

MyCalculator.new.calculate(
  received_amount: 100,
  received_currency: 'EUR',
  charged_currency: 'USD',
  commission: 10,
  exchange_commission: 15
).to_h
# =>
#   {
#     :received_amount => #<Money fractional:10000 currency:EUR>,
#     :charged_amount => #<Money fractional:13072 currency:USD>,
#     :fee => #<Money fractional:1307 currency:USD>,
#     :exchange_fee => #<Money fractional:1765 currency:USD>,
#     :exchange_rate => 1
#    }

# Changing the order
class MyCalculator
  Order[
    :exchange_commission,
    :exchange,
    :commission
  ]
end

MyCalculator.new.calculate(
  received_amount: 100,
  received_currency: 'EUR',
  charged_currency: 'USD',
  commission: 10,
  exchange_commission: 15
).to_h
# =>
#   {
#     :received_amount => #<Money fractional:10000 currency:EUR>,
#     :charged_amount => #<Money fractional:13072 currency:USD>,
#     :fee => #<Money fractional:1111 currency:EUR>,
#     :exchange_fee => #<Money fractional:1961 currency:USD>,
#     :exchange_rate => 1
#    }
```

## Development

- [x] Custom exchanger
  - [x] If exchanging is not needed, it is not executed
- [x] Commission for operation
- [x] Commission for exchange
- [x] No matter whether received or charged amount is provided, the calculation result is the same
- [x] User-defined order of commissions aplying and exchanging
- [ ] Custom commissions and exchanges in order

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mrexox/commissioner.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
