#property copyright "GitHub Copilot"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

datetime g_last_bar_time = 0;

input string InpBotName = "TrendRsiBot";
input int    InpFastEma = 20;
input int    InpSlowEma = 50;
input int    InpRsiPeriod = 14;
input double InpLotSize = 0.01;
input double InpRiskPercent = 1.0;
input int    InpStopLoss = 150;
input int    InpTakeProfit = 300;
input int    InpTrailingStop = 50;
input int    InpMaxPositions = 1;
input bool   InpUseTrailing = true;

int OnInit()
{
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTick()
{
   if(!IsTradeAllowed())
      return;

   if(!IsNewBar())
      return;

   if(CountOpenPositions() >= InpMaxPositions)
      return;

   double fastCurrent = iMA(_Symbol, PERIOD_CURRENT, InpFastEma, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowCurrent = iMA(_Symbol, PERIOD_CURRENT, InpSlowEma, 0, MODE_EMA, PRICE_CLOSE, 1);
   double fastPrev    = iMA(_Symbol, PERIOD_CURRENT, InpFastEma, 0, MODE_EMA, PRICE_CLOSE, 2);
   double slowPrev    = iMA(_Symbol, PERIOD_CURRENT, InpSlowEma, 0, MODE_EMA, PRICE_CLOSE, 2);
   double rsiCurrent  = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE, 1);
   double rsiPrev     = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE, 2);

   bool longSignal  = (fastCurrent > slowCurrent && fastPrev <= slowPrev && rsiCurrent > 50.0 && rsiPrev <= 50.0);
   bool shortSignal = (fastCurrent < slowCurrent && fastPrev >= slowPrev && rsiCurrent < 50.0 && rsiPrev >= 50.0);

   if(longSignal)
   {
      OpenBuy();
      return;
   }

   if(shortSignal)
   {
      OpenSell();
      return;
   }

   if(InpUseTrailing)
      ManageTrailingStops();
}

void OnTimer()
{
   if(InpUseTrailing)
      ManageTrailingStops();
}

bool IsNewBar()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2)
      return false;

   datetime currentBarTime = (datetime)rates[0].time;
   if(g_last_bar_time == currentBarTime)
      return false;

   g_last_bar_time = currentBarTime;
   return true;
}

int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }
   return count;
}

void OpenBuy()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = 0.0;
   double tp = 0.0;

   if(InpStopLoss > 0)
      sl = ask - InpStopLoss * _Point;

   if(InpTakeProfit > 0)
      tp = ask + InpTakeProfit * _Point;

   double lot = CalculateLot(ask, sl);
   bool result = trade.Buy(lot, _Symbol, ask, sl, tp, "TrendRsiBot Long");

   if(!result)
      Print("Buy order failed. Error: ", GetLastError());
}

void OpenSell()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0.0;
   double tp = 0.0;

   if(InpStopLoss > 0)
      sl = bid + InpStopLoss * _Point;

   if(InpTakeProfit > 0)
      tp = bid - InpTakeProfit * _Point;

   double lot = CalculateLot(bid, sl);
   bool result = trade.Sell(lot, _Symbol, bid, sl, tp, "TrendRsiBot Short");

   if(!result)
      Print("Sell order failed. Error: ", GetLastError());
}

double CalculateLot(double entryPrice, double stopLossPrice)
{
   if(InpRiskPercent <= 0.0)
      return InpLotSize;

   double stopDistance = MathAbs(entryPrice - stopLossPrice);
   if(stopDistance <= 0.0)
      return InpLotSize;

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickValue <= 0.0)
      return InpLotSize;

   double lot = riskAmount / MathMax(stopDistance * tickValue, 1e-8);
   lot = MathMax(0.01, lot);
   lot = MathMin(lot, InpLotSize * 10.0);

   return NormalizeDouble(lot, 2);
}

void ManageTrailingStops()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
      {
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double currentStop = PositionGetDouble(POSITION_SL);
         double newStop = NormalizeDouble(currentBid - InpTrailingStop * _Point, _Digits);

         if(currentStop == 0.0 || newStop > currentStop)
         {
            trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP));
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentStop = PositionGetDouble(POSITION_SL);
         double newStop = NormalizeDouble(currentAsk + InpTrailingStop * _Point, _Digits);

         if(currentStop == 0.0 || newStop < currentStop)
         {
            trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP));
         }
      }
   }
}
