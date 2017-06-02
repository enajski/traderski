require 'coinbase/wallet'
require_relative 'lib/nbp_client'

class Traderski
  def initialize(coinbase_api_key = ENV["COINBASE_API_KEY"], coinbase_api_secret = ENV["COINBASE_API_SECRET"])
    @coinbase_client = Coinbase::Wallet::Client.new(
      api_key: coinbase_api_key,
      api_secret: coinbase_api_secret
    )

    @nbp_client = NBPClient.new
  end

  def accounts
    @coinbase_client.accounts
  end

  def account_ids
    accounts.map { |account| account.fetch("id") }
  end

  def buys(account_id)
    @coinbase_client.list_buys(account_id)
  end

  def all_buys
    @all_buys ||= account_ids.map { |account_id| buys(account_id) }.flatten
  end

  def buys_by_year(year)
    all_buys.select { |buy| Date.parse(buy.fetch("created_at")).year == year }
  end

  def clear_buys_cache
    @all_buys = nil
  end

  def total_cost
    total_amount_currency_adjusted(all_buys)
  end

  def total_cost_by_year(year)
    total_amount_currency_adjusted(buys_by_year(year))
  end

  def sells(account_id)
    @coinbase_client.list_sells(account_id)
  end

  def all_sells
    @all_sells ||= account_ids.map { |account_id| sells(account_id) }.flatten
  end

  def sells_by_year(year)
    all_sells.select { |sell| Date.parse(sell.fetch("created_at")).year == year }
  end

  def clear_sells_cache
    @all_sells = nil
  end

  def total_gain
    total_amount_currency_adjusted(all_sells)
  end

  def total_gain_by_year(year)
    total_amount_currency_adjusted(sells_by_year(year))
  end

  def total_amount(operations)
    operations.
      map { |buy| buy.fetch("total").fetch("amount") }.
      map(&:to_f).
      reduce(&:+)
  end

  def total_amount_currency_adjusted(operations)
    operations.
      map do |buy|
        currency_code = buy.fetch("total").fetch("currency")
        value = buy.fetch("total").fetch("amount").to_f
        date = Date.parse(buy.fetch("created_at"))

        convert_currency_to_pln(currency_code, value, date)
      end.
      reduce(&:+)
  end

  def eur_to_pln(value, date)
    convert_currency_to_pln("EUR", value, date)
  end

  def convert_currency_to_pln(currency_code, value, date)
    rate = @nbp_client.last_working_day_exchange_rate(currency_code, date)

    value * rate
  end
end
