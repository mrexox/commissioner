# Commissioner


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'commissioner'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install easy_commissioner

## Usage

### First, configure the gem

```ruby
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

## Development

- [x] Custom exchanger
  - [x] If exchanging is not needed, it is not executed
- [x] Commission for operation
- [x] Commission for exchange
- [x] No matter whether received or charged amount is provided, the calculation result is the same
- [ ] User-defined order of commissions aplying

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mrexox/commissioner.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
