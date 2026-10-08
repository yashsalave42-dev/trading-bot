# Trading Bot Collection

This repository contains a set of MetaTrader 5 Expert Advisors for educational and research use.

## Included EAs

- `MQL5/Experts/ScalpingBot.mq5` — fast market-entry scalper for short-term intraday trading
- `MQL5/Experts/GridTrendHybrid.mq5` — trend-following EA with layered grid entries and risk limits

## Strategy overview

### Scalping Bot
- EMA trend filter
- RSI momentum confirmation
- tight stop loss
- low spread filter
- max trades per direction
- optional trailing stop

### Grid Trend Hybrid
- EMA trend detection
- RSI confirmation
- layered grid entries during trend continuation
- risk caps and drawdown checks
- position limits and optional trail

## How to use

1. Copy the `MQL5` folder to your MetaTrader 5 installation.
2. Open MetaEditor.
3. Compile each EA.
4. Attach to a chart and test thoroughly in Strategy Tester.

## Important

No trading system is guaranteed to be profitable. Always backtest, optimize carefully, and use realistic risk management before live deployment.
