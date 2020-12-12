lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'commissioner'
Commissioner.configure {|c| c.exchanger = ->(from, to, amount) { [Money.from_amount(amount.to_f, to), 1] } }
