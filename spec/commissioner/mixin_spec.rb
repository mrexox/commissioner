RSpec.describe Commissioner::Mixin do
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
