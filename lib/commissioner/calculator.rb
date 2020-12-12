require 'money'

module Commissioner
  class Calculator
    AmountUnknown = Class.new(StandardError)
    CommissionerArityInvalid = Class.new(StandardError)

    HELP_MESSAGE = 'You must provider either charged_amount (with charged_currency) or received_amount (with received_currency). If none or both are non-zero, the service cannot know how to handle this.'.freeze
    private_constant :HELP_MESSAGE

    def initialize(params, config:)
      @charged_amount = guess_amount(params[:charged_amount], params[:charged_currency])
      @received_amount = guess_amount(params[:received_amount], params[:received_currency])

      @exchange_commission = params[:exchange_commission] || 0
      @commission = params[:commission] || 0

      unless config.exchanger.is_a?(Proc) && config.exchanger.arity == 3
        raise CommissionerArityInvalid.new("'exchanger' setting must be a lambda with arity of 3")
      end

      @exchanger = config.exchanger
      @rounding_mode =
        case config.rounding_mode
        when :up
          BigDecimal::ROUND_UP
        when :down
          BigDecimal::ROUND_DOWN
        when :half_even
          BigDecimal::ROUND_HALF_EVEN
        else
          BigDecimal::ROUND_HALF_UP
        end
    end

    def calculate
      if !empty?(@received_amount) && empty?(@charged_amount)
        @charged_amount = calculate_for_received
      elsif !empty?(@charged_amount) && empty?(@received_amount)
        @received_amount = calculate_for_charged
      else
        raise AmountUnknown.new(HELP_MESSAGE)
      end

      OpenStruct.new(
        received_amount: @received_amount,
        charged_amount: @charged_amount,
        fee: @fee,
        exchange_fee: @exchange_fee,
        exchange_rate: @exchange_rate
      )
    end

    private

    attr_reader :exchange_commission, :commission, :exchanger

    def empty?(amount)
      amount.nil? || amount.zero?
    end

    def calculate_for_received
      amount = @received_amount

      amount, @exchange_fee = add_commission(amount, exchange_commission)

      amount, @exchange_rate = exchange(amount) if @charged_amount.currency != @received_amount.currency

      amount, @fee = add_commission(amount, commission)

      amount
    end

    def calculate_for_charged
      amount = @charged_amount

      amount, @fee = reduce_commission(amount, commission)

      amount, @exchange_rate = exchange(amount) if @charged_amount.currency != @received_amount.currency

      amount, @exchange_fee = reduce_commission(amount, exchange_commission)

      amount
    end

    def guess_amount(amount, currency)
      case amount
      when Money
        amount
      when Numeric
        Money.from_amount(amount, currency) if currency.is_a?(String)
      when NilClass
        Money.new(0, currency) if currency.is_a?(String)
      end
    end

    def reduce_commission(amount, commission)
      return 0 unless commission
      fee = round(amount.to_f * commission / 100, amount.currency.to_s)
      amount -= fee

      [amount, fee]
    end

    def add_commission(amount, commission)
      return 0 unless commission
      fee = round(amount.to_f * commission / (100 - commission), amount.currency.to_s)
      amount += fee

      [amount, fee]
    end

    def round(decimal, currency)
      Money.with_rounding_mode(@rounding_mode) do
        Money.from_amount(decimal, currency)
      end
    end

    def exchange(amount)
      exchanger.call(@charged_amount.currency.to_s, @received_amount.currency.to_s, amount)
    end
  end
end
