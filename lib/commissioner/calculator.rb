# frozen_string_literal: true

require 'ostruct'
require 'money'

module Commissioner
  class Calculator
    AmountUnknown = Class.new(StandardError)
    CommissionerArityInvalid = Class.new(StandardError)

    class Operator
      OPERATIONS = {
        exchange: ->(op) { op.exchange },
        commission: ->(op) { op.apply_commission(op.commission, :operation) },
        exchange_commission: ->(op) { op.apply_commission(op.exchange_commission, :exchange) if op.to != op.from }
      }.freeze

      attr_reader :commission, :exchange_commission, :exchanger, :to, :from, :exchange_fee, :fee, :exchange_rate,
                  :amount

      def initialize(params)
        @amount = params[:amount]
        @commission = params[:commission]
        @exchange_commission = params[:exchange_commission]
        @exchanger = params[:exchanger]
        @rounding_mode = params[:rounding_mode]
        @commission_action = params[:commission_action]
        @from = params[:from_currency]
        @to = params[:to_currency]
      end

      def apply_order(order)
        order.each do |operation|
          OPERATIONS[operation]&.call(self)
        end
      end

      def apply_commission(commission, type)
        return 0 unless commission

        if @commission_action == :reduce
          fee = round(@amount.to_f * commission / 100, @amount.currency.to_s)
          @amount -= fee
        else
          fee = round(@amount.to_f * commission / (100 - commission), @amount.currency.to_s)
          @amount += fee
        end

        case type
        when :exchange
          @exchange_fee = fee
        else
          @fee = fee
        end
      end

      def round(decimal, currency)
        Money.with_rounding_mode(@rounding_mode) do
          Money.from_amount(decimal, currency)
        end
      end

      def exchange
        @amount, @exchange_rate = exchanger.call(from, to, @amount)
      end
    end

    HELP_MESSAGE = 'You must provider either charged_amount (with charged_currency) '\
                   'or received_amount (with received_currency). If none or both are '\
                   'non-zero, the service cannot know how to handle this.'
    DEFAULT_ORDER = %i[
      commission
      exchange
      exchange_commission
    ].freeze

    private_constant :HELP_MESSAGE
    private_constant :DEFAULT_ORDER
    private_constant :Operator

    def initialize(params, config:, order: DEFAULT_ORDER)
      @charged_amount = guess_amount(params[:charged_amount], params[:charged_currency])
      @received_amount = guess_amount(params[:received_amount], params[:received_currency])

      @exchange_commission = params[:exchange_commission] || 0
      @commission = params[:commission] || 0

      unless config.exchanger.is_a?(Proc) && config.exchanger.arity == 3
        raise CommissionerArityInvalid, "'exchanger' setting must be a lambda with arity of 3"
      end

      @exchanger = config.exchanger
      @order = order
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
      @result = OpenStruct.new(
        received_amount: @received_amount,
        charged_amount: @charged_amount,
        fee: 0,
        exchange_fee: 0,
        exchange_rate: 0
      )

      if !empty?(@charged_amount) && @received_amount.zero?
        calculate_for_charged
      elsif !empty?(@received_amount) && @charged_amount.zero?
        calculate_for_received
      else
        raise AmountUnknown, HELP_MESSAGE
      end

      @result
    end

    private

    def empty?(amount)
      amount.nil? || amount.zero?
    end

    def calculate_for_charged
      operator = Operator.new(
        from_currency: @charged_amount.currency.to_s,
        to_currency: @received_amount.currency.to_s,
        amount: @charged_amount,
        commission: @commission,
        exchange_commission: @exchange_commission,
        exchanger: @exchanger,
        rounding_mode: @rounding_mode,
        commission_action: :reduce
      )

      operator.apply_order(@order)

      @result.received_amount = operator.amount
      @result.fee = operator.fee if operator.fee
      @result.exchange_fee = operator.exchange_fee if operator.exchange_fee
      @result.exchange_rate = operator.exchange_rate
    end

    def calculate_for_received
      operator = Operator.new(
        from_currency: @charged_amount.currency.to_s,
        to_currency: @received_amount.currency.to_s,
        amount: @received_amount,
        commission: @commission,
        exchange_commission: @exchange_commission,
        exchanger: @exchanger,
        rounding_mode: @rounding_mode,
        commission_action: :add
      )

      operator.apply_order(@order.reverse)

      @result.charged_amount = operator.amount
      @result.fee = operator.fee if operator.fee
      @result.exchange_fee = operator.exchange_fee if operator.exchange_fee
      @result.exchange_rate = operator.exchange_rate
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
  end
end
