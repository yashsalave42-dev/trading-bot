# Grid Trend Hybrid Bot

This branch contains a hybrid MQL5 Expert Advisor combining:

- trend-following logic using EMA direction
- RSI confirmation
- controlled grid entries
- risk-limited position management
- optional trailing stop
- max drawdown and max open trades protection

## Files

- `MQL5/Experts/GridTrendHybrid.mq5` — main Expert Advisor

## Strategy summary

- Detect market trend using EMA alignment
- Confirm with RSI momentum
- On trend pullbacks, add controlled grid entries
- Use fixed stop loss and take profit spacing
- Stop opening new grids after max exposure or drawdown thresholds

## Recommended settings

- Symbol: EURUSD or GBPUSD
- Timeframe: M15 or H1
- Backtest thoroughly before using on live account

## Important

This is educational and experimental code. Grid systems can accumulate risk quickly if not properly parameterized.
