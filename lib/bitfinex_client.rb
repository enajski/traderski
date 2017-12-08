require 'bitfinex-rb'
require "pry"

class BitfinexTrader
  def initialize()
    Bitfinex::Client.configure do |conf|
      conf.secret = ENV["BITFINEX_API_SECRET"]
      conf.api_key = ENV["BITFINEX_API_KEY"]

      # uncomment if you want to use version 2 of the API
      # which is opt-in at the moment
      #
      # conf.use_api_v2
    end

    @bitfinex_client = Bitfinex::Client.new
  end

  def symbols
    @symbols ||= @bitfinex_client.symbols_details
  end

  def balances
    @bitfinex_client.balances
  end

  def usd_balance
    available("usd")
  end

  def available(currency)
    balances.
      find { |balance| balance["currency"] == currency }.
      fetch("available").
      to_f
  end

  def held_currencies
    @held_currencies ||= balances.map { |s| s.fetch("currency") }
  end

  def ticker_from_part_of(ticker_name)
    ticker_name[0..2]
  end

  def ticker_to_part_of(ticker_name)
    ticker_name[3..6]
  end

  def denominated_in_usd?(pair)
    ticker_to_part_of(pair) == "usd"
  end

  def current_prices(pair)
    @bitfinex_client.ticker(pair)
  end

  def history(pair)
    @bitfinex_client.mytrades(pair)
  end

  def average_price(history)
    history.
      map { |order| order["price"].to_f }.
      instance_eval { reduce(:+) / size.to_f }
  end

  def strategy
    symbol = symbols.
      select { |symbol| denominated_in_usd?(symbol.fetch("pair")) }.
      sample

    chosen_pair = symbol.fetch("pair")

    puts ""
    puts "**************************************"
    puts "Let's have a look at #{chosen_pair}..."

    current_market_price = current_prices(chosen_pair)

    mid = current_market_price.fetch("mid").to_f
    low = current_market_price.fetch("low").to_f
    high = current_market_price.fetch("high").to_f
    ask = current_market_price.fetch("ask").to_f

    puts current_market_price

    pair_history = history(chosen_pair)

    puts "So far I've traded #{chosen_pair} like this:"
    puts pair_history

    buys = pair_history.select { |s| s["type"] == "Buy"}

    if buys.empty? && ((low / mid) > (mid / high))
      puts "Nothing so far, huh?"
      puts "Let's buy!"
      action = "buy"
      amount = (symbol.fetch("minimum_order_size").to_f * 1.1).to_s
    elsif buys.empty? && ((low / mid) <= (mid / high))
      puts "Nothing so far, huh?"
      puts "Price seems close to it's high point."
      puts "Let's wait."
      action = nil
    elsif (mid / average_price(buys)) <= 0.9
      puts "The current price #{mid} is less than x0.9 (x#{mid / average_price(buys)}) my average buy #{average_price(pair_history)}"
      puts "Let's buy some more!"
      action = "buy"
      amount = (symbol.fetch("minimum_order_size").to_f * 1.1).to_s
    elsif (mid / average_price(buys)) >= 1.1
      puts "The current price #{mid} is more than x1.1 (x#{mid / average_price(buys)}) my average buy #{average_price(pair_history)}"
      puts "Let's sell!"
      action = "sell"
      amount = (symbol.fetch("minimum_order_size").to_f * 1.0).to_s
    else
      puts "The current price #{mid} is x#{mid / average_price(buys)} my average buy #{average_price(pair_history)}"
      puts "Let's wait."
      action = nil
    end

    base_strategy = {side: action,
                     symbol: chosen_pair,
                     type: "exchange market",
                     price: ask.to_s,
                     amount: amount}
  end

  def execute_order(strategy)
    return unless strategy[:side]

    usd_value = strategy[:amount].to_f * strategy[:price].to_f
    current_balance = usd_balance()

    if strategy[:side] == "buy" && usd_value > current_balance
      puts "Not enough USD! You have #{current_balance} and the amount needed is #{usd_value}"
      return nil
    end

    # if strategy[:side] == "sell" && strategy[:amount].to_f > available(ticker_from_part_of(strategy[:symbol]))
    #   puts "Less then "
    #   return nil
    # end

    order_result = @bitfinex_client.new_order(strategy[:symbol], strategy[:amount], strategy[:type], strategy[:side], strategy[:price])

    message = "#{strategy[:side]} #{strategy[:amount]} #{strategy[:symbol]} for #{usd_value} dollars"
    puts message
    `say #{message}`
    puts order_result
    order_result
  end

  def loop_trading
    loop do
      begin
        execute_order(strategy())
      rescue Exception => e
        puts e
      end

      sleep 60
    end
  end
end

trader = BitfinexTrader.new

binding.pry

puts "bye!"