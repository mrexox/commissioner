# frozen_string_literal: true

RSpec.describe Commissioner::Mixin do
  context 'with simple configuration' do
    before do
      Commissioner.configure do |config|
        config.exchanger = ->(_from, to, amount) { Money.from_amount(amount.to_f, to) }
      end

      class MyCalculator
        include Commissioner::Mixin
      end
    end

    it 'behaves the same as explicit call' do
      result = MyCalculator.new.calculate(charged_amount: 10, charged_currency: 'EUR', received_currency: 'USD')

      expect(result.charged_amount).to eq Money.from_amount(10, 'EUR')
      expect(result.received_amount).to eq Money.from_amount(10, 'USD')
    end
  end

  context 'with changed order' do
    before do
      Commissioner.configure do |config|
        config.exchanger = lambda { |from, to, amount|
          Money.from_amount(amount.to_f, amount.currency.to_s == to ? from : to)
        }
      end

      class MyCalculator
        include Commissioner::Mixin

        Order[
          :commission,
          :exchange_commission,
          :exchange
        ]
      end
    end

    describe 'Calculator' do
      subject(:calculate) do
        MyCalculator.new.calculate(
          charged_amount: charged_amount,
          charged_currency: charged_currency,
          received_amount: received_amount,
          received_currency: received_currency,
          commission: commission,
          exchange_commission: exchange_commission
        )
      end

      let(:charged_amount) { 100 }
      let(:charged_currency) { 'EUR' }
      let(:received_amount) { 0 }
      let(:received_currency) { 'USD' }
      let(:commission) { 5 }
      let(:exchange_commission) { 10 }

      it 'calculates properly' do
        result = calculate

        expect(result.charged_amount).to eq Money.from_amount(charged_amount, charged_currency)
        expect(result.received_amount).to eq Money.from_amount(100 - 5 - 9.5, received_currency)
        expect(result.fee).to eq Money.from_amount(5, charged_currency)
        expect(result.exchange_fee).to eq Money.from_amount(9.5, charged_currency)
      end

      context 'for received amount given' do
        let(:charged_amount) { 0 }
        let(:received_amount) { 100 }

        it 'calculates properly' do
          result = calculate

          # 0.9 * 0.95 * 116.96 ~ 100.00
          expect(result.charged_amount).to eq Money.from_amount(116.96, charged_currency)
          expect(result.received_amount).to eq Money.from_amount(received_amount, received_currency)
          expect(result.fee).to eq Money.from_amount(5.85, charged_currency)
          expect(result.exchange_fee).to eq Money.from_amount(11.11, charged_currency)
        end
      end
    end
  end
end
