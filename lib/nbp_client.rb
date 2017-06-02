require "httparty"

class NBPClient
  include HTTParty
  headers 'Content-Type' => 'application/json', "Accept" => 'application/json'

  def last_working_day_exchange_rate(code, date)
    last_working_day = previous_working_day(date)

    exchange_rate(code, last_working_day)
  end

  def previous_working_day(date)
    date = Date.parse(date) unless date.is_a?(Date)

    prev_date = date.prev_day

    if prev_date.saturday? || prev_date.sunday?
      previous_working_day(prev_date)
    else
      prev_date
    end
  end

  def exchange_rate(code, date = "today")
    fetch_exchange_rate(code, date.to_s).
      fetch("rates").
      first.
      fetch("mid")
  end

  def fetch_exchange_rate(code, date)
    self.class.get("http://api.nbp.pl/api/exchangerates/rates/a/#{code}/#{date}")
  end
end
