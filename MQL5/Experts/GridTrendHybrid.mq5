#property copyright "GitHub Copilot"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

datetime g_last_bar_time = 0;

input string InpBotName = "GridTrendHybrid";
input int    InpTrendFastEma = 20;
input int    InpTrendSlowEma = 50;
input int    InpRsiPeriod = 14;
input int    InpRsiLevel = 50;
input int    InpGridStepPoints = 120;
input int    InpGridDistancePoints = 240;
input int    InpGridMaxOrders = 4;
input int    InpStopLoss = 200;
input int    InpTakeProfit = 400;
input int    InpTrailingStop = 80;
input int    InpMaxSpreadPoints = 20;
input double InpBaseLot = 0.01;
input double InpGridMultiplier = 1.3;
input double InpMaxDailyLossPercent = 5.0;
input bool   InpUseTrailing = true;

bool IsNewBar()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2)
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
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double loss    = balance - equity;
   double percent = (loss / MathMax(balance, 1e-8)) * 100.0;
   return (percent < InpMaxDailyLossPercent);
}

int CountDirectionOrders(int direction)
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

void OpenMarketOrder(int direction)
{
   double price = (direction == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0.0;
   double tp = 0.0;

   if(InpStopLoss > 0)
      sl = (direction == POSITION_TYPE_BUY) ? price - InpStopLoss * _Point : price + InpStopLoss * _Point;
   if(InpTakeProfit > 0)
      tp = (direction == POSITION_TYPE_BUY) ? price + InpTakeProfit * _Point : price - InpTakeProfit * _Point;

   if(direction == POSITION_TYPE_BUY)
      trade.Buy(InpBaseLot, _Symbol, price, sl, tp, "GridTrendHybrid Buy");
   else
      trade.Sell(InpBaseLot, _Symbol, price, sl, tp, "GridTrendHybrid Sell");
}

void AddGridOrder(int direction)
{
   if(CountDirectionOrders(direction) >= InpGridMaxOrders)
      return;

   int count = CountDirectionOrders(direction);
   double volume = InpBaseLot * MathPow(InpGridMultiplier, count);
   volume = NormalizeDouble(volume, 2);

   double lastPrice = 0.0;
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
      {
         lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         break;
      }
   }

   if(lastPrice == 0.0)
      return;

   double offset = InpGridStepPoints * _Point;
   double price = (direction == POSITION_TYPE_BUY) ? lastPrice - offset : lastPrice + offset;

   if(direction == POSITION_TYPE_BUY)
      trade.Buy(volume, _Symbol, price, 0.0, 0.0, "GridTrendHybrid Grid Buy");
   else
      trade.Sell(volume, _Symbol, price, 0.0, 0.0, "GridTrendHybrid Grid Sell");
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

   double fastCurrent = iMA(_Symbol, PERIOD_CURRENT, InpTrendFastEma, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowCurrent = iMA(_Symbol, PERIOD_CURRENT, InpTrendSlowEma, 0, MODE_EMA, PRICE_CLOSE, 1);
   double fastPrev    = iMA(_Symbol, PERIOD_CURRENT, InpTrendFastEma, 0, MODE_EMA, PRICE_CLOSE, 2);
   double slowPrev    = iMA(_Symbol, PERIOD_CURRENT, InpTrendSlowEma, 0, MODE_EMA, PRICE_CLOSE, 2);
   double rsiCurrent  = iRSI(_Symbol, PERIOD_CURRENT, InpRsiPeriod, PRICE_CLOSE, 1);

   bool upTrend = (fastCurrent > slowCurrent && fastPrev > slowPrev);
   bool downTrend = (fastCurrent < slowCurrent && fastPrev < slowPrev);
   bool bullishTrend = upTrend && (rsiCurrent > InpRsiLevel);
   bool bearishTrend = downTrend && (rsiCurrent < InpRsiLevel);

   int buyCount = CountDirectionOrders(POSITION_TYPE_BUY);
   int sellCount = CountDirectionOrders(POSITION_TYPE_SELL);

   if(buyCount == 0 && bullishTrend)
   {
      OpenMarketOrder(POSITION_TYPE_BUY);
      return;
   }

   if(sellCount == 0 && bearishTrend)
   {
      OpenMarketOrder(POSITION_TYPE_SELL);
      return;
   }

   if(bullishTrend && buyCount > 0 && buyCount < InpGridMaxOrders)
      AddGridOrder(POSITION_TYPE_BUY);

   if(bearishTrend && sellCount > 0 && sellCount < InpGridMaxOrders)
      AddGridOrder(POSITION_TYPE_SELL);

   if(InpUseTrailing)
      ManageTrailingStops();
}
