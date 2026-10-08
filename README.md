# Trading Bot (MQL5 Expert Advisor)

This repository contains a simple MQL5 Expert Advisor designed for Metatrader 5.

## Strategy

- Trend-following system using EMA crossover
- RSI confirmation filter
- Risk-based position sizing
- Optional trailing stop
- Single-symbol / current-chart operation

## Files

- `MQL5/Experts/TrendRsiBot.mq5` – Expert Advisor source code

## How to use

1. Copy the `MQL5` folder into your MetaEditor working directory or the MQL5 folder in your MT5 installation.
2. Open MetaEditor in MetaTrader 5.
3. Compile the file.
4. Attach `TrendRsiBot` to a chart.
5. Adjust inputs as needed.

## Recommended setup

- Symbol: major FX pair, e.g. EURUSD
- Timeframe: H1 or H4
- Backtest before live use

## Important note

This bot is for educational purposes only. Do not run it in live trading without proper testing and risk controls.
