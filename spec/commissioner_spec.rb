# frozen_string_literal: true

RSpec.describe Commissioner do
  it 'has a version number' do
    expect(Commissioner::VERSION).not_to be nil
  end

  context 'with invalid exchanger' do
    before do
      Commissioner.configure do |config|
        config.exchanger = 2
      end
    end

    it 'raises CommissionerArityInvalid' do
      expect do
        Commissioner.calculate(charged_amount: 1, charged_currency: 'EUR',
                               received_currency: 'USD')
      end.to raise_error(Commissioner::Calculator::CommissionerArityInvalid)
    end
  end

  context 'with exchanger wrong arity' do
    before do
      Commissioner.configure do |config|
        config.exchanger = -> {}
      end
    end

    it 'raises CommissionerArityInvalid' do
      expect do
        Commissioner.calculate(charged_amount: 1, charged_currency: 'EUR',
                               received_currency: 'USD')
      end.to raise_error(Commissioner::Calculator::CommissionerArityInvalid)
    end
  end

  context 'with dummy exchanger' do
    before do
      Commissioner.configure do |config|
        config.exchanger = lambda { |from, to, amount|
          Money.from_amount(amount.to_f, amount.currency.to_s == to ? from : to)
        }
      end
    end

    it 'calculates for amounts as money' do
      result = Commissioner.calculate(charged_amount: Money.from_amount(10, 'EUR'),
                                      received_amount: Money.from_amount(0, 'USD'))

      expect(result.charged_amount).to eq Money.from_amount(10, 'EUR')
      expect(result.received_amount).to eq Money.from_amount(10, 'USD')
      expect(result.fee).to be_zero
      expect(result.exchange_fee).to be_zero
    end

    it 'raises AmountUnknown if both amounts given' do
      expect do
        Commissioner.calculate(charged_amount: Money.from_amount(10, 'EUR'),
                               received_amount: Money.from_amount(10, 'USD'))
      end.to raise_error(Commissioner::Calculator::AmountUnknown)
    end

    it 'raises AmountUnknown if no amount given' do
      expect { Commissioner.calculate({}) }.to raise_error(Commissioner::Calculator::AmountUnknown)
    end

    it 'calculates proper currencies for charged' do
      result = Commissioner.calculate(charged_amount: 1, charged_currency: 'EUR', received_currency: 'USD')

      expect(result.charged_amount).to eq Money.from_amount(1, 'EUR')
      expect(result.received_amount).to eq Money.from_amount(1, 'USD')
      expect(result.fee).to be_zero
      expect(result.exchange_fee).to be_zero
    end

    it 'calculates proper currencies for received' do
      result = Commissioner.calculate(received_amount: 1, received_currency: 'EUR', charged_currency: 'USD')

      expect(result.received_amount).to eq Money.from_amount(1, 'EUR')
      expect(result.charged_amount).to eq Money.from_amount(1, 'USD')
      expect(result.fee).to be_zero
      expect(result.exchange_fee).to be_zero
    end

    it 'reduces commission for charged' do
      result = Commissioner.calculate(charged_amount: 100, charged_currency: 'EUR', received_currency: 'USD',
                                      commission: 1)

      expect(result.fee.to_f).to eq 1.0
    end

    it 'adds commission for received' do
      result = Commissioner.calculate(received_amount: 100, received_currency: 'EUR', charged_currency: 'USD',
                                      commission: 1)

      expect(result.fee.to_f).to eq 1.01
    end

    it 'does not apply exchange commission if currencies are same' do
      result = Commissioner.calculate(charged_amount: 100, charged_currency: 'EUR', received_currency: 'EUR',
                                      commission: 10, exchange_commission: 25)

      expect(result.received_amount).to eq Money.from_amount(90, 'EUR')
      expect(result.exchange_fee).to eq Money.zero('EUR')
      expect(result.fee).to eq Money.from_amount(10, 'EUR')
    end

    context 'with rounding mode up' do
      before do
        Commissioner.configure do |config|
          config.rounding_mode = :up
        end
      end

      it 'adds commission for received' do
        result = Commissioner.calculate(received_amount: 100, received_currency: 'EUR', charged_currency: 'USD',
                                        commission: 1)

        expect(result.fee.to_f).to eq 1.02
      end
    end
  end
end
