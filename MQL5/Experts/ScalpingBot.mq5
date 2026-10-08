#property copyright "GitHub Copilot"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

datetime g_last_bar_time = 0;

input string InpBotName = "ScalpingBot";
input int    InpFastEma = 9;
input int    InpSlowEma = 21;
input int    InpRsiPeriod = 14;
input int    InpStopLoss = 30;
input int    InpTakeProfit = 60;
input int    InpTrailingStop = 20;
input int    InpMaxSpreadPoints = 12;
input int    InpMaxTrades = 1;
input double InpLotSize = 0.01;
input double InpMaxDailyLossPercent = 4.0;
input bool   InpUseTrailing = true;

bool IsNewBar()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, 2, rates) < 2)
      return false;

   datetime currentBarTime = rates[0].time;
   if(g_last_bar_time == currentBarTime)
      return false;

   g_last_bar_time = currentBarTime;
   return true;
}

bool SpreadOk()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= InpMaxSpreadPoints);
}

bool RiskLimitOk()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double loss = balance - equity;
   double percent = (loss / MathMax(balance, 1e-8)) * 100.0;
   return (percent < InpMaxDailyLossPercent);
}

int CountOpenTrades(int direction)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_TYPE) == direction)
         count++;
   }
   return count;
}

void OpenLong()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = ask - InpStopLoss * _Point;
   double tp = ask + InpTakeProfit * _Point;
   trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "ScalpingBot Long");
}

void OpenShort()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = bid + InpStopLoss * _Point;
   double tp = bid - InpTakeProfit * _Point;
   trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "ScalpingBot Short");
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
      double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentStop = PositionGetDouble(POSITION_SL);
      double newStop = 0.0;

      if(type == POSITION_TYPE_BUY)
      {
         newStop = NormalizeDouble(currentPrice - InpTrailingStop * _Point, _Digits);
         if(currentStop == 0.0 || newStop > currentStop)
            trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP));
      }
      else if(type == POSITION_TYPE_SELL)
      {
         newStop = NormalizeDouble(currentPrice + InpTrailingStop * _Point, _Digits);
         if(currentStop == 0.0 || newStop < currentStop)
            trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP));
      }
   }
}

int OnInit()
{
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   if(InpUseTrailing)
      ManageTrailingStops();
}

void OnTick()
{
   if(!IsTradeAllowed())
      return;

   if(!IsNewBar())
      return;

   if(!SpreadOk())
      return;

   if(!RiskLimitOk())
      return;

   if(CountOpenTrades(POSITION_TYPE_BUY) >= InpMaxTrades && CountOpenTrades(POSITION_TYPE_SELL) >= InpMaxTrades)
      return;

   double fastCurrent = iMA(_Symbol, PERIOD_M1, InpFastEma, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowCurrent = iMA(_Symbol, PERIOD_M1, InpSlowEma, 0, MODE_EMA, PRICE_CLOSE, 1);
   double rsiValue = iRSI(_Symbol, PERIOD_M1, InpRsiPeriod, PRICE_CLOSE, 1);

   bool longSignal = (fastCurrent > slowCurrent && rsiValue > 50.0);
   bool shortSignal = (fastCurrent < slowCurrent && rsiValue < 50.0);

   if(longSignal && CountOpenTrades(POSITION_TYPE_BUY) < InpMaxTrades)
      OpenLong();
   else if(shortSignal && CountOpenTrades(POSITION_TYPE_SELL) < InpMaxTrades)
      OpenShort();

   if(InpUseTrailing)
      ManageTrailingStops();
}
