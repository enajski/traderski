# Traderski

## Coinbase

```
COINBASE_API_KEY=<KEY> COINBASE_API_SECRET=<SECRET> ./bin/traderski


pry(main)> client.total_gain_by_year(2017)
pry(main)> client.total_cost_by_year(2017)
```

## Bitfinex

```
BITFINEX_API_KEY=<KEY> BITFINEX_API_SECRET=<SECRET> ruby lib/bitfinex_client.rb

pry(main)> trader.loop_trading
```