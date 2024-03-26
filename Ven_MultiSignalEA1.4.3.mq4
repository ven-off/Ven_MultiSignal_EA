//+------------------------------------------------------------------+
//|                                       Ven_MultiSignalEA1.0.0.mq4 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

/*
使用的指标，按顺序: average_channel_candles, fisher_no_repainting, vortex_indicator, schaff trend cycle, waddah attar explosion2.4
多单信号：指标名字后面都带 _1_
 average_channel_candles 价格收盘在上边界上方
 fisher_no_repainting 出现绿线，其实就是大于零
 vortex_indicator 蓝线在红线上方
 schaff trend cycle  线是蓝色
 waddah attar explosion 绿柱 高于黄线
多单平仓
 schaff trend cycle  线是黄色
止损点数，止盈点数 pips
保本和跟踪止损
可以用ATR的百分比来代替各个点数
根据止损点数，自动计算手数
*/

#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayInt.mqh>

enum ENUM_ACC_AVE_METHOD
{
Adxvma,
Ahrens_moving_average,
ALXMA,
DEMA,
DSEMA,
EMAD,
EMA,
FRAMA,
HMA,
IE2,
Integral_of_line_regression_slope,
Instantaneous_trendline,
Laguerre_filter,
Leader_exponential_moving_average,
LSMA,
LWMA,
McGinley_Dynamic,
McNicholl_ema,
Non_lag_moving_average,
PWMA,
RMTA,
SMA,
SDEC,
Sine_weighted_moving_average,
SMMA,
Smoother,
Super_smoother,
Three_pole_Ehlers_Butterworth,
Three_pole_Ehlers_smoother,
TMA,
TEMA,
Two_pole_Ehlers_Butterworth,
Two_pole_ehlers_smoother,
VEMA,
VWMA,
Zero_lag_dema,
Zero_lag_moving_average,
Zero_lag_tema
};

enum ENUM_ACC_PRICE_TYPE
{
close, //Close
open,  //Open
high,  //High
low,  //Low
Median,
Typical,
Weighted,
Average,
Average_median_body,
Trend_biased_price,
Trend_biased_extreme_price,
HA_close,
HA_open,
HA_high,
HA_low,
HA_median,
HA_typical,
HA_weighted,
HA_average,
HA_median_body,
HA_trend_biased_price,
HA_trend_biased_extreme_price,
HA_close_better_formula,
HA_open_better_formula,
HA_high_better_formula,
HA_low_better_formula,
HA_median_better_formula,
HA_typical_better_formula,
HA_weighted_better_formula,
HA_average_better_formula,
HA_median_body_better_formula,
HA_trend_biased_price_better_formula,
HA_trend_biased_extreme_price_better_formula
};


input string split3 = "=============< Trading Settings >============="; //=============< Trading Settings >=============
enum ENUM_LOT_MODE {FIXED_LOT_SIZE,BY_RISK_PERCENT,BY_FIXED_RISK};
input ENUM_LOT_MODE     set_lot_mode        = BY_FIXED_RISK;
input double            fixed_lot_size      = 0.1;
input double            risk_percentage     = 2;        //risk_percentage %
input double            fixed_risk_value    = 50;       
enum ENUM_STOP_MODE {BY_PIPS,BY_ATR};
input ENUM_STOP_MODE    set_sl_tp_mode      = BY_PIPS;
input double            set_sl_pips         = 60;       //set_sl_pips (0:off)
input double            set_tp_pips         = 100;
input double            atr_sl_multiplier   = 1;        //atr_sl_multiplier (0:off)
input double            atr_tp_multiplier   = 2;
input int               atr_period          = 14;
input string split6 = "=============< Breakeven & TrailingStop >============="; //=============< Breakeven & TrailingStop >=============
input double            breakeven_trigger   = 0;
input double            trailing_trigger = 0;
input double            trailing_init_profit = 10;
input double            trailing_step   = 1;
input string split9 = "=============< Indicator Parameters >============="; //=============< Indicator Parameters >=============
input string            ind1_name = "Averages Channel Candles + alerts 2.07";
input int                   ind1_average_period     = 34;
input ENUM_ACC_AVE_METHOD   ind1_average_method     = EMA;
input ENUM_ACC_PRICE_TYPE   ind1_price_to_use       = 0;
input string            ind2_name = "Fisher_no_repainting";
input int               ind2_range_periods      = 10;
input double            ind2_price_smoothing    = 0.3;
input double            ind2_index_smoothing    = 0.3;
input string            ind3_name ="vortex-indicator";
input int               ind3_vi_length  = 14;
input string            ind4_name = "waddah attar explosion averages nmc alerts 2_4";
input int               ind4_macd_price = 0;
input int               ind4_fast_ma    = 20;
input int               ind4_slow_ma    = 40;
input int               ind4_ma_method  = 1;
input int               ind4_bands_length = 21;
input int               ind4_bands_price = 0;
input double            ind4_bands_dev  = 2.0;
input int               ind4_sensitive  = 150;
input int               ind4_atr_period = 21;
input string            ind5_name = "Schaff Trend Cycle - adjustable signal mtf";
input int               ind5_schaff_period = 10;
input int               ind5_fast_macd      = 23;
input int               ind5_slow_macd      = 50;
input double            ind5_signal_period  = 3.0;
input bool              enable_close_by_signal = true;
input string split12 = "=============< Other Settings >============="; //=============< Other Settings >=============
input color         color_buy   = clrOrange;
input color         color_sell  = clrAqua;
input int           daily_market_close_minutes = 5;
input int           line_thick  = 3;
input int           ea_magic   = 324674;
input string        ea_comment = "ven";

datetime time_rec = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
    ChartSetInteger(0,CHART_SHOW_GRID,false);
//--- create timer
   EventSetTimer(60);
   time_rec = iTime(_Symbol,PERIOD_CURRENT,0);
   
   //---
    ObjectsDeleteAll(0,"arr");
    //--- 显示历史箭头 
    for(int i=0;i<OrdersHistoryTotal();i++)
    {
        if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)&&OrderSymbol()==_Symbol&&OrderMagicNumber()==ea_magic)
        {
            int         i_ticket    = OrderTicket();
            datetime    i_time      = OrderOpenTime();
            int         i_type      = OrderType();
            //---
            int shift = iBarShift(_Symbol,PERIOD_CURRENT,i_time);
            string i_name = "arr"+string(i_ticket);
            if(ObjectFind(0,i_name)<0)
            {
                if(i_type==0) ArrowCreate(i_name,0,i_time,iLow(_Symbol,PERIOD_CURRENT,shift),line_thick,color_buy,233,ANCHOR_TOP);
                if(i_type==1) ArrowCreate(i_name,0,i_time,iHigh(_Symbol,PERIOD_CURRENT,shift),line_thick,color_sell,234,ANCHOR_BOTTOM);
            }
        }
    }    
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    //--- 准备指标数据
    //average_channel_candles
    double acc_upper1 = iCustom(_Symbol,PERIOD_CURRENT,ind1_name,0,ind1_average_period,ind1_average_method,ind1_price_to_use,12,1);
    double acc_lower1 = iCustom(_Symbol,PERIOD_CURRENT,ind1_name,0,ind1_average_period,ind1_average_method,ind1_price_to_use,15,1);
    //fisher_no_repainting
    double fnr1 = iCustom(_Symbol,PERIOD_CURRENT,ind2_name,ind2_range_periods,ind2_price_smoothing,ind2_index_smoothing,0,1);
    //vortex_indicator
    double vi_plus1  = iCustom(_Symbol,PERIOD_CURRENT,ind3_name,ind3_vi_length,0,1);
    double vi_plus2  = iCustom(_Symbol,PERIOD_CURRENT,ind3_name,ind3_vi_length,0,2);
    double vi_minus1 = iCustom(_Symbol,PERIOD_CURRENT,ind3_name,ind3_vi_length,1,1);
    double vi_minus2 = iCustom(_Symbol,PERIOD_CURRENT,ind3_name,ind3_vi_length,1,2);
    //waddah attar explosion
    double wae1_1 = iCustom(_Symbol,PERIOD_CURRENT,ind4_name,0,ind4_macd_price,ind4_fast_ma,ind4_slow_ma,ind4_ma_method,ind4_bands_length,ind4_bands_price,ind4_bands_dev,ind4_sensitive,ind4_atr_period,0,1);
    double wae2_1 = iCustom(_Symbol,PERIOD_CURRENT,ind4_name,0,ind4_macd_price,ind4_fast_ma,ind4_slow_ma,ind4_ma_method,ind4_bands_length,ind4_bands_price,ind4_bands_dev,ind4_sensitive,ind4_atr_period,1,1);
    double wae3_1 = iCustom(_Symbol,PERIOD_CURRENT,ind4_name,0,ind4_macd_price,ind4_fast_ma,ind4_slow_ma,ind4_ma_method,ind4_bands_length,ind4_bands_price,ind4_bands_dev,ind4_sensitive,ind4_atr_period,2,1);
    double wae4_1 = iCustom(_Symbol,PERIOD_CURRENT,ind4_name,0,ind4_macd_price,ind4_fast_ma,ind4_slow_ma,ind4_ma_method,ind4_bands_length,ind4_bands_price,ind4_bands_dev,ind4_sensitive,ind4_atr_period,3,1);
    double wae_level1 = iCustom(_Symbol,PERIOD_CURRENT,ind4_name,0,ind4_macd_price,ind4_fast_ma,ind4_slow_ma,ind4_ma_method,ind4_bands_length,ind4_bands_price,ind4_bands_dev,ind4_sensitive,ind4_atr_period,4,1);
    double wae_green1 = (wae1_1==EMPTY_VALUE?wae2_1:wae1_1);
    double wae_red1   = (wae3_1==EMPTY_VALUE?wae4_1:wae3_1);
    //schaff trend cycle
    double stc1_1 = iCustom(_Symbol,PERIOD_CURRENT,ind5_name,0,ind5_schaff_period,ind5_fast_macd,ind5_slow_macd,ind5_signal_period,0,1);
    double stc2_1 = iCustom(_Symbol,PERIOD_CURRENT,ind5_name,0,ind5_schaff_period,ind5_fast_macd,ind5_slow_macd,ind5_signal_period,1,1);
    double stc_bull1 = (stc2_1==EMPTY_VALUE?stc1_1:EMPTY_VALUE);
    double stc_bear1 = stc2_1;
    //atr
    double atr = iATR(_Symbol,PERIOD_CURRENT,atr_period,1);
    
    //--- 开仓功能
    bool token = false;
    //---
    if(Period()<PERIOD_D1)
    {
        if(time_rec<iTime(_Symbol,PERIOD_CURRENT,0))
        {
            time_rec = iTime(_Symbol,PERIOD_CURRENT,0);
            token = true;
        }
    }else
    {
        if(TimeCurrent()>=iTime(_Symbol,PERIOD_CURRENT,0)+daily_market_close_minutes*60)
        {
            if(time_rec<iTime(_Symbol,PERIOD_CURRENT,0))
            {
                time_rec = iTime(_Symbol,PERIOD_CURRENT,0);
                token = true;
            }
        }
    }
    
    if(token)
    {
        //--- 显示vi点
        if(vi_plus1>vi_minus1&&vi_plus2<=vi_minus2) ArrowCreate("vi_"+TimeToString(Time[1],TIME_DATE|TIME_MINUTES),0,Time[1],Low[1],line_thick,clrLime,108,ANCHOR_TOP);
        if(vi_plus1<vi_minus1&&vi_plus2>=vi_minus2) ArrowCreate("vi_"+TimeToString(Time[1],TIME_DATE|TIME_MINUTES),0,Time[1],High[1],line_thick,clrRed,108,ANCHOR_BOTTOM);
        
        //--- 止损点数计算
        int trade_sl_point = int(set_sl_pips*10);
        int trade_tp_point = int(set_tp_pips*10);
        if(set_sl_tp_mode==BY_ATR)
        {
            trade_sl_point = int(atr*atr_sl_multiplier*MathPow(10,_Digits));
            trade_tp_point = int(atr*atr_tp_multiplier*MathPow(10,_Digits));
        }
        //--- 手数计算
        double trade_lots = fixed_lot_size;
        if(set_lot_mode==BY_RISK_PERCENT)
        {
            if(trade_sl_point>0)
            {
                trade_lots = AccountBalance()*risk_percentage*0.01/(trade_sl_point*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE));
                trade_lots = NormalizeDouble(trade_lots,2);
            }
        }
        if(set_lot_mode==BY_FIXED_RISK)
        {
            if(trade_sl_point>0)
            {
                trade_lots = fixed_risk_value/(trade_sl_point*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE));
                trade_lots = NormalizeDouble(trade_lots,2);
            }
        }
        

        
        if(trade_lots<0.01) trade_lots = 0.01;
        //--- 多单 开仓
        if(HC_PositionSumCalc("number",0,2,ea_magic)==0)
        {
            if(Close[1]>acc_upper1&&fnr1>0&&vi_plus1>vi_minus1&&stc_bull1!=EMPTY_VALUE)
            {
                if(wae_green1!=EMPTY_VALUE&&wae_green1>wae_level1)
                {
                    int res = HC_PositionOpen_By_Point(0,trade_lots,_Symbol,trade_sl_point,trade_tp_point,ea_magic,ea_comment);
                }
            }
        }
        //--- 空单 开仓
        if(HC_PositionSumCalc("number",1,2,ea_magic)==0)
        {
            if(Close[1]<acc_lower1&&fnr1<0&&vi_plus1<vi_minus1&&stc_bear1!=EMPTY_VALUE)
            {
                if(wae_red1!=EMPTY_VALUE&&wae_red1>wae_level1)
                {
                    int res = HC_PositionOpen_By_Point(1,trade_lots,_Symbol,trade_sl_point,trade_tp_point,ea_magic,ea_comment);
                }
            }
        }
        //---
        token = false;
    }
    
    if(enable_close_by_signal)
    {
        if(stc_bull1!=EMPTY_VALUE) HC_PositionsCloseAll(1,2,ea_magic);
        if(stc_bear1!=EMPTY_VALUE) HC_PositionsCloseAll(0,2,ea_magic);
    }
    
    //--- 
    if(breakeven_trigger>0) HC_BreakEven_for_EverySinglePosition(2,int(breakeven_trigger*10),5,ea_magic);
    if(trailing_trigger>0) HC_TrailingStop_for_EverySinglePosition(2,int(trailing_trigger*10),int(trailing_init_profit*10),int(trailing_step*10),ea_magic);
    
    //--- 设置箭头大小
    for(int i=0;i<ObjectsTotal();i++)
    {
        string i_name = ObjectName(0,i);
        if(ObjectGetInteger(0,i_name,OBJPROP_TYPE)!=OBJ_TREND) continue;
        if(StringFind(i_name,"#")<0) continue;
        //---
        if(ObjectGetInteger(0,i_name,OBJPROP_COLOR)==clrBlue)
        {
            ObjectSetInteger(0,i_name,OBJPROP_STYLE,STYLE_SOLID);
            ObjectSetInteger(0,i_name,OBJPROP_WIDTH,line_thick);
            ObjectSetInteger(0,i_name,OBJPROP_COLOR,color_buy);
            break;
        }
        if(ObjectGetInteger(0,i_name,OBJPROP_COLOR)==clrRed)
        {
            ObjectSetInteger(0,i_name,OBJPROP_STYLE,STYLE_SOLID);
            ObjectSetInteger(0,i_name,OBJPROP_WIDTH,line_thick);
            ObjectSetInteger(0,i_name,OBJPROP_COLOR,color_sell);
            break;
        }
    
    }
    
    
    //--- 显示持仓 
    for(int i=0;i<OrdersTotal();i++)
    {
        if(OrderSelect(i,SELECT_BY_POS)&&OrderSymbol()==_Symbol&&OrderMagicNumber()==ea_magic)
        {
            int         i_ticket    = OrderTicket();
            datetime    i_time      = OrderOpenTime();
            int         i_type      = OrderType();
            //---
            int shift = iBarShift(_Symbol,PERIOD_CURRENT,i_time);
            if(shift==0) continue;
            string i_name = "arr"+string(i_ticket);
            if(ObjectFind(0,i_name)<0)
            {
                if(i_type==0) ArrowCreate(i_name,0,i_time,iLow(_Symbol,PERIOD_CURRENT,shift),line_thick,color_buy,233,ANCHOR_TOP);
                if(i_type==1) ArrowCreate(i_name,0,i_time,iHigh(_Symbol,PERIOD_CURRENT,shift),line_thick,color_sell,234,ANCHOR_BOTTOM);
            }
        }
    } 
    
   
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| 市价单开仓功能                                                  |
//+------------------------------------------------------------------+
bool HC_PositionOpen(int type,double volume,string symbol = "current",double stoploss = 0,double takeprofit = 0,ulong magic = 0,string comment = NULL)
{
    if(symbol == "current") symbol = _Symbol;
    double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
    //---
    int res = 0;
    if(type == 0) res = OrderSend(symbol,OP_BUY ,volume,ask,100,stoploss,takeprofit,comment,int(magic),0,clrOrange);
    if(type == 1) res = OrderSend(symbol,OP_SELL,volume,bid,100,stoploss,takeprofit,comment,int(magic),0,clrAqua  );
    return (res>0?true:false);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HC_PositionOpen_By_Point(int type,double volume,string symbol = "current",int sl_point = 0,int tp_point = 0,ulong magic = 0,string comment = NULL)  //by points
{
    if(symbol == "current") symbol = _Symbol;
    double point  = SymbolInfoDouble(symbol,SYMBOL_POINT);
    double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
    //---
    int res = 0;
    if(type == 0) res = OrderSend(symbol,OP_BUY ,volume,ask,100,(sl_point>0?ask-sl_point*point:0),(tp_point>0?ask+tp_point*point:0),comment,(int)magic,0,clrAqua);
    if(type == 1) res = OrderSend(symbol,OP_SELL,volume,bid,100,(sl_point>0?bid+sl_point*point:0),(tp_point>0?bid-tp_point*point:0),comment,(int)magic,0,clrOrange);
    return (res>0?true:false);
}
//+------------------------------------------------------------------+
//| 市价单平仓和部分平仓功能 根据订单号                            |
//+------------------------------------------------------------------+
bool HC_PositionClose(ulong ticket)
{
    if(OrderSelect(int(ticket),SELECT_BY_TICKET))
    {
        string symbol = OrderSymbol();
        double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
        double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
        if(OrderType()==OP_BUY ) return OrderClose(int(ticket),OrderLots(),bid,100,clrBisque);
        if(OrderType()==OP_SELL) return OrderClose(int(ticket),OrderLots(),ask,100,clrBisque);
    }
    return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HC_PositionPartialClose_By_Volume(ulong ticket,double volume)
{
    if(OrderSelect(int(ticket),SELECT_BY_TICKET))
    {
        string symbol = OrderSymbol();
        double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
        double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
        //---
        if(volume>0)
        {
            double close_volume = volume;
            if(close_volume>OrderLots()) close_volume = OrderLots();
            if(OrderType()==OP_BUY ) return OrderClose(int(ticket),close_volume,bid,100,clrNONE);
            if(OrderType()==OP_SELL) return OrderClose(int(ticket),close_volume,ask,100,clrNONE);
        }   
    }
    return false;
}
//---
bool HC_PositionPartialClose_By_Percent(ulong ticket,double percent)  // percent < 1
{
    if(OrderSelect(int(ticket),SELECT_BY_TICKET))
    {
        string symbol = OrderSymbol();
        double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
        double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
        //---
        if(percent>0)
        {
            double close_volume = OrderLots()*percent;
            if(close_volume<0.01)        close_volume = 0.01;
            if(close_volume>OrderLots()) close_volume = OrderLots();
            if(OrderType()==OP_BUY ) return OrderClose(int(ticket),close_volume,bid,100,clrNONE);
            if(OrderType()==OP_SELL) return OrderClose(int(ticket),close_volume,ask,100,clrNONE);
        }   
    }
    return false;
}
//+------------------------------------------------------------------+
//| 市价单一次全平功能                                              |
//+------------------------------------------------------------------+
void HC_PositionsCloseAll(int type=2,int profit_type=2,ulong magic=0,string symbol="current",string comment = NULL) // !xxx 表示严格匹配
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal(); // number of open positions
    //---
    CArrayInt ticket_list;
//--- iterate over all open positions
    for(int i = total - 1; i >= 0; i--)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        int  i_ticket = OrderTicket();
        //---
        int i_type = OrderType();
        if(i_type>=2) continue;
        if(type == 0 && i_type != OP_BUY ) continue;
        if(type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic   != 0     && magic   != OrderMagicNumber())   continue;
        if(symbol  != "all" && symbol  != OrderSymbol())        continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() < 0) continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        //---
        ticket_list.Add(i_ticket);
    }
    //--- FIFO
    ticket_list.Sort();
    for(int i=0;i<ticket_list.Total();i++)
    {
        HC_PositionClose(ticket_list.At(i));
    }
    return;
}
//--- 市价单 集体 部分平仓 功能
void HC_PositionsPartialCloseAll(int type = 2,int profit_type = 2,string partial_type = "volume",double param = 0,ulong magic = 0,string symbol = "current",string comment = NULL)
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal(); // number of open positions
    //---
    CArrayInt ticket_list;
//--- iterate over all open positions
    for(int i = total - 1; i >= 0; i--)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        int  i_ticket = OrderTicket();
        //---
        int i_type = OrderType();
        if(i_type>=2) continue;
        if(type == 0 && i_type != OP_BUY ) continue;
        if(type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic   != 0     && magic   != OrderMagicNumber()) continue;
        if(symbol  != "all" && symbol  != OrderSymbol()) continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() < 0) continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        //---
        ticket_list.Add(i_ticket);
        //---
        
    }
    //---
    //--- FIFO
    ticket_list.Sort();
    for(int i=0;i<ticket_list.Total();i++)
    {
        if(partial_type=="volume")  HC_PositionPartialClose_By_Volume(ticket_list.At(i),param);
        if(partial_type=="percent") HC_PositionPartialClose_By_Percent(ticket_list.At(i),param);
    }

    return;
}


//--- 市价单 隐藏止盈止损的平仓功能
void HC_PositionsCloseAll_By_HiddenStop(int type = 2,int profit_type = 2,int stoploss_point = 0,int takeprofit_point = 0,ulong magic = 0,string symbol = "current",string comment = NULL)
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal(); // number of open positions
    //---
    CArrayInt ticket_list;
//--- iterate over all open positions
    for(int i = total - 1; i >= 0; i--)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        int  i_ticket = OrderTicket();
        //---
        int    i_type   = OrderType();
        string i_symbol = OrderSymbol();
        //---
        if(i_type>=2) continue;
        if(type == 0 && i_type != OP_BUY ) continue;
        if(type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic   != 0     && magic   != OrderMagicNumber())   continue;
        if(symbol  != "all" && symbol  != i_symbol)             continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() < 0 ) continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        //--- 
        double i_ask = SymbolInfoDouble(i_symbol,SYMBOL_ASK);
        double i_bid = SymbolInfoDouble(i_symbol,SYMBOL_BID);
        double i_open_price = OrderOpenPrice();
        double i_point = SymbolInfoDouble(i_symbol,SYMBOL_POINT);
        //---
        ticket_list.Add(i_ticket);
        //---
    }
    //---
    ticket_list.Sort();
    for(int i=0;i<ticket_list.Total();i++)
    { 
        if(OrderSelect(ticket_list.At(i),SELECT_BY_TICKET))
        {
            int     i_ticket    = ticket_list.At(i);
            int     i_type      = OrderType();
            string  i_symbol    = OrderSymbol();
            double  i_ask       = SymbolInfoDouble(i_symbol,SYMBOL_ASK);
            double  i_bid       = SymbolInfoDouble(i_symbol,SYMBOL_BID);
            double  i_open_price = OrderOpenPrice();
            double  i_point     = SymbolInfoDouble(i_symbol,SYMBOL_POINT);
            //---
            if(i_type==OP_BUY)
            {
                if(stoploss_point  >0&&i_bid<i_open_price-stoploss_point  *i_point) HC_PositionClose(i_ticket);
                if(takeprofit_point>0&&i_bid>i_open_price+takeprofit_point*i_point) HC_PositionClose(i_ticket);
            }
            if(i_type==OP_SELL)
            {
                if(stoploss_point  >0&&i_ask>i_open_price+stoploss_point  *i_point) HC_PositionClose(i_ticket);
                if(takeprofit_point>0&&i_ask<i_open_price-takeprofit_point*i_point) HC_PositionClose(i_ticket);
            } 
        }
    }
    return;
}

//+------------------------------------------------------------------+
//| 市价单修改功能 根据订单号                                      |
//+------------------------------------------------------------------+
bool HC_PositionModify(ulong ticket,double stoploss,double takeprofit)
{
    if(OrderSelect(int(ticket),SELECT_BY_TICKET))
    {
        double pre_stoploss   = OrderStopLoss();
        double pre_takeprofit = OrderTakeProfit();
        //---
        double next_stoploss = NormalizeDouble(stoploss,(int)SymbolInfoInteger(OrderSymbol(),SYMBOL_DIGITS));
        if(stoploss==0)  next_stoploss = 0;
        if(stoploss==-1) next_stoploss = pre_stoploss;
        double next_takeprofit = NormalizeDouble(takeprofit,(int)SymbolInfoInteger(OrderSymbol(),SYMBOL_DIGITS));
        if(takeprofit==0)  next_takeprofit = 0;
        if(takeprofit==-1) next_takeprofit = pre_takeprofit;
        //---
        if(next_stoploss==pre_stoploss&&next_takeprofit==pre_takeprofit) return true;
        return OrderModify(int(ticket),OrderOpenPrice(),next_stoploss,next_takeprofit,0,clrNONE);
    }
    return false;
}
//--- 根据 现价+点数 的方式 设置止盈止损
bool HC_PositionModify_By_Point(ulong ticket,int sl_point,int tp_point)    //by points
{
    if(OrderSelect(int(ticket),SELECT_BY_TICKET))
    {
        string symbol = OrderSymbol();
        double point  = SymbolInfoDouble(symbol,SYMBOL_POINT);
        int    type   = OrderType();
        double pre_stoploss   = OrderStopLoss();
        double pre_takeprofit = OrderTakeProfit();
        double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
        double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
        //---
        if(type == OP_BUY)
        {
            double next_stoploss = ask - sl_point * point;
            if(sl_point==0)  next_stoploss = 0;
            if(sl_point==-1) next_stoploss = NormalizeDouble(pre_stoploss,(int)SymbolInfoInteger(OrderSymbol(),SYMBOL_DIGITS));
            double next_takeprofit = ask + tp_point * point;
            if(tp_point==0)  next_takeprofit = 0;
            if(tp_point==-1) next_takeprofit = NormalizeDouble(pre_takeprofit,(int)SymbolInfoInteger(OrderSymbol(),SYMBOL_DIGITS));
            //---
            if(next_stoploss==pre_stoploss&&next_takeprofit==pre_takeprofit) return true;
            return OrderModify(int(ticket),OrderOpenPrice(),next_stoploss,next_takeprofit,0,clrNONE);
        }
        if(type == OP_SELL)
        {
            double next_stoploss = bid + sl_point * point;
            if(sl_point==0)  next_stoploss = 0;
            if(sl_point==-1) next_stoploss = NormalizeDouble(pre_stoploss,(int)SymbolInfoInteger(OrderSymbol(),SYMBOL_DIGITS));
            double next_takeprofit = bid - tp_point * point;
            if(tp_point==0)  next_takeprofit = 0;
            if(tp_point==-1) next_takeprofit = NormalizeDouble(pre_takeprofit,(int)SymbolInfoInteger(OrderSymbol(),SYMBOL_DIGITS));
            //---
            if(next_stoploss==pre_stoploss&&next_takeprofit==pre_takeprofit) return true;
            return OrderModify(int(ticket),OrderOpenPrice(),next_stoploss,next_takeprofit,0,clrNONE);
        }
    }
    return false;
}
//+------------------------------------------------------------------+
//| 市价单批量修改止盈止损  按价格                                 |
//+------------------------------------------------------------------+
void HC_PositionsModifyAll(double stoploss,double takeprofit,int type,int profit_type = 2,ulong magic = 0,string symbol = "current",string comment = NULL)
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal(); // number of open positions
//--- iterate over all open positions
    for(int i = total - 1; i >= 0; i--)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        ulong  i_ticket = OrderTicket();
        //---
        int i_type = OrderType();
        if(i_type>=2) continue;
        if(type == 0 && i_type != OP_BUY ) continue;
        if(type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic   != 0     && magic   != OrderMagicNumber()) continue;
        if(symbol  != "all" && symbol  != OrderSymbol())  continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() < 0)  continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        //---
        HC_PositionModify(i_ticket,stoploss,takeprofit);

    }
    return;
}

//+------------------------------------------------------------------+
//| 市价单批量修改止盈止损  按点数                                 |
//+------------------------------------------------------------------+
void HC_PositionsModifyAll_By_Point(int stoploss_point,int takeprofit_point,int type,int profit_type = 2,ulong magic = 0,string symbol = "current",string comment = NULL)
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal(); // number of open positions
//--- iterate over all open positions
    for(int i = total - 1; i >= 0; i--)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        ulong i_ticket = OrderTicket();
        //---
        int i_type = OrderType();
        if(i_type>=2) continue;
        if(type == 0 && i_type != OP_BUY ) continue;
        if(type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic   != 0     && magic   != OrderMagicNumber()) continue;
        if(symbol  != "all" && symbol  != OrderSymbol()) continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() < 0) continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        //---
        HC_PositionModify_By_Point(i_ticket,stoploss_point,takeprofit_point);

    }
    return;
}

//+------------------------------------------------------------------+
//| 订单统计功能 - 总和                                             |
//+------------------------------------------------------------------+
double HC_PositionSumCalc(string sum_type,int type = 2,int profit_type = 2,ulong magic = 0,string symbol = "current",string comment = NULL)
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal(); // number of open positions
    double sum_value = 0;
    for(int i = 0; i < total; i++)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        ulong  i_ticket = OrderTicket();
        string i_symbol = OrderSymbol();
        //---
        int i_type = OrderType();
        if(i_type>=2) continue;
        if(type == 0 && i_type != OP_BUY ) continue;
        if(type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic   != 0     && magic   != OrderMagicNumber()) continue;
        if(symbol  != "all" && symbol  != OrderSymbol()) continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() < 0) continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        //---
        if(sum_type == "number")            sum_value += 1;
        //---
        double i_volume = OrderLots();
        if(sum_type == "volume")            sum_value += i_volume;
        //---
        double i_profit      = OrderProfit();
        double i_profit_full = i_profit + OrderSwap();
        if(sum_type == "profit")             sum_value += i_profit;
        if(sum_type == "profit_full")        sum_value += i_profit_full;
        if(sum_type == "profit_point")      sum_value += NormalizeDouble(i_profit / (i_volume * SymbolInfoDouble(i_symbol,SYMBOL_TRADE_TICK_VALUE)),0);
        if(sum_type == "profit_point_full") sum_value += NormalizeDouble(i_profit_full / (i_volume * SymbolInfoDouble(i_symbol,SYMBOL_TRADE_TICK_VALUE)),0);
    }
//---
    return sum_value;
}

//风险手数单独做一个函数统计
double HC_PositionSumRiskVolume(ulong magic = 0,string symbol = "current",string comment = NULL)
{
    if(symbol == "current") symbol = _Symbol;
    double long_volume  = HC_PositionSumCalc("volume",0,2,magic,symbol,comment);
    double short_volume = HC_PositionSumCalc("volume",1,2,magic,symbol,comment);
    return long_volume - short_volume;
}

//+------------------------------------------------------------------+
//| 订单统计功能 - 均值                                             |
//+------------------------------------------------------------------+
double HC_PositionAveCalc(string ave_type,int type = 2,int profit_type = 2,ulong magic = 0,string symbol = "current",string comment = NULL)
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal(); // number of open positions
    double sum_value  = 0;
    double sum_volume = 0;
    for(int i = 0; i < total; i++)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        ulong  i_ticket = OrderTicket();
        double i_volume = OrderLots();
        //string i_symbol = PositionGetString(POSITION_SYMBOL);
        //---
        int i_type = OrderType();
        if(i_type>=2) continue;
        if(type == 0 && i_type != OP_BUY ) continue;
        if(type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic   != 0     && magic   != OrderMagicNumber()) continue;
        if(symbol  != "all" && symbol  != OrderSymbol()) continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() < 0) continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        //---
        if(type==0||type==1)
        {
            if(ave_type == "openprice")   sum_value += i_volume*OrderOpenPrice();
            if(ave_type == "stoploss")    sum_value += i_volume*OrderStopLoss();
            if(ave_type == "takeprofit")  sum_value += i_volume*OrderTakeProfit();
            sum_volume += i_volume;
        }
        if(type==2)
        {
            if(ave_type == "openprice")   sum_value += (i_type==OP_BUY?1:-1)*i_volume*OrderOpenPrice();
            if(ave_type == "stoploss")    sum_value += (i_type==OP_BUY?1:-1)*i_volume*OrderStopLoss();
            if(ave_type == "takeprofit")  sum_value += (i_type==OP_BUY?1:-1)*i_volume*OrderTakeProfit();
            sum_volume += (i_type==OP_BUY?1:-1)*i_volume;
        }
    }
//---
    if(sum_volume==0) return 0;
    double ave_value = sum_value / sum_volume;
    return NormalizeDouble(ave_value,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS));
}


//+------------------------------------------------------------------+
//| 创建CPosition类                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CPositon Class Defination                                        |
//+------------------------------------------------------------------+
class CPosition : public CObject
  {
private:
    int                 m_ticket;
    datetime            m_opentime;
    int                 m_type;
    double              m_volume;
    string              m_symbol;
    double              m_openprice;
    double              m_stoploss;
    double              m_takeprofit;
    double              m_currentprice;
    double              m_commission;
    double              m_swap;
    double              m_profit;
    double              m_profit_full;
    long                m_profit_point;
    long                m_profit_point_full;
    long                m_magic;
    string              m_comment;
    long                m_inner_id;
    string              m_inner_comment;
    //---
public:
                     CPosition() {}
                    ~CPosition() {}
    //--- get values
    int                 Ticket(void)                const   { return(m_ticket);         }
    datetime            Opentime(void)              const   { return(m_opentime);       }
    int                 Type(void)                  const   { return(m_type);           }
    double              Volume(void)                const   { return(m_volume);         }
    string              Symbol(void)                const   { return(m_symbol);         }
    double              Openprice(void)             const   { return(m_openprice);      }
    double              Stoploss(void)              const   { return(m_stoploss);       }
    double              Takeprofit(void)            const   { return(m_takeprofit);     }
    double              Currentprice(void)          const   { return(m_currentprice);   }
    double              Commission(void)            const   { return(m_commission);     }
    double              Swap(void)                  const   { return(m_swap);           }
    double              Profit(void)                const   { return(m_profit);         }
    double              ProfitFull(void)            const   { return(m_profit_full);    }
    long                ProfitPoint(void)           const   { return(m_profit_point);         }
    long                ProfitPointFull(void)       const   { return(m_profit_point_full);    }
    long                Magic(void)                 const   { return(m_magic);          }
    string              Comment(void)               const   { return(m_comment);        }
    //---
    long                InnerID(void)               const   { return(m_inner_id);       }
    void                InnerID(int inner_id)               { m_inner_id = inner_id;    }
    string              InnerComment(void)          const   { return(m_inner_comment);  }
    void                InnerComment(string inner_comment)  { m_inner_comment = inner_comment;  }
    //--- calculations
    bool                AssignByTicket(int ticket);
    long                Calc_ProfitPoint(void);
    long                Calc_ProfitPointFull(void);
    
  };
//+------------------------------------------------------------------+
bool CPosition::AssignByTicket(int ticket)
{
    if(OrderSelect(ticket,SELECT_BY_TICKET))
    {
        m_ticket            = ticket;
        m_opentime          = (datetime)OrderOpenTime();
        if(OrderType()==OP_BUY)  m_type = OP_BUY;
        if(OrderType()==OP_SELL) m_type = OP_SELL;
        m_volume            = OrderLots();
        m_symbol            = OrderSymbol();
        m_openprice         = OrderOpenPrice();
        m_stoploss          = OrderStopLoss();
        m_takeprofit        = OrderTakeProfit();
        if(m_type==OP_BUY)  m_currentprice = SymbolInfoDouble(m_symbol,SYMBOL_BID);
        if(m_type==OP_SELL) m_currentprice = SymbolInfoDouble(m_symbol,SYMBOL_ASK);
        m_commission        = OrderCommission();
        m_swap              = OrderSwap();
        m_profit            = OrderProfit();
        m_profit_full       = m_commission+m_swap+m_profit;
        m_profit_point      = Calc_ProfitPoint();
        m_profit_point_full = Calc_ProfitPointFull();
        m_magic             = OrderMagicNumber();
        m_comment           = OrderComment();
        return true;
    }
    else printf("%s: INVALID TICKET %d",__FUNCTION__,ticket);
    return false;
}
//+------------------------------------------------------------------+
long CPosition::Calc_ProfitPoint(void)
{
    //point = profit/(lot*value); 
    long points = (long)NormalizeDouble(m_profit/(m_volume*SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_VALUE)),0);
    return points;
}
//+------------------------------------------------------------------+
long CPosition::Calc_ProfitPointFull(void)
{
    //point = profit/(lot*value); 
    long points_full = (long)NormalizeDouble(m_profit_full/(m_volume*SymbolInfoDouble(m_symbol,SYMBOL_TRADE_TICK_VALUE)),0);
    return points_full;
}
//+------------------------------------------------------------------+

//--- 类定义之外的相关函数
//+------------------------------------------------------------------------------------------+
//| 类实例的赋值功能 这个功能有些多余，订单之间用assign by ticket 功能，就可以传递参数   |
//+------------------------------------------------------------------------------------------+
void PositionAssignByAnother(CPosition* to,CPosition* from)
{
    to.AssignByTicket(from.Ticket());
}


//+------------------------------------------------------------------+
//| 订单极值查找功能                                                |
//+------------------------------------------------------------------+
CPosition* HC_Position_Extremum_Check(string check_type,string position_prop,int position_type=2,int profit_type=2,string symbol="current",long magic=0,string comment=NULL,ulong ignore_ticket1=-1,ulong ignore_ticket2=-1)
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal();
//---
    int         extreme_ticket      = 0;
    double      extreme_value       = 0;
//---
    for(int i = 0; i < total; i++)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        int    i_ticket = OrderTicket();
        string i_symbol = OrderSymbol();
        if(ignore_ticket1>=0&&i_ticket==ignore_ticket1) continue;
        if(ignore_ticket2>=0&&i_ticket==ignore_ticket2) continue;
        //---
        int i_type = OrderType();
        if(i_type>=2) continue;
        if(position_type == 0 && i_type != OP_BUY ) continue;
        if(position_type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic   != 0     && magic   != OrderMagicNumber())   continue;
        if(symbol  != "all" && symbol  != OrderSymbol())        continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() < 0 ) continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        //---
        double check_value = 0;
        //---
        double i_volume = OrderLots();
        double i_profit = OrderProfit();
        double i_swap   = OrderSwap();
        double i_profit_full = i_profit + i_swap;
        //---

        //--- integer props
        if(position_prop=="ticket")                 check_value = (double)i_ticket;
        if(position_prop=="opentime")               check_value = (double)OrderOpenTime();
        if(position_prop=="magic")                  check_value = (double)OrderMagicNumber();
        if(position_prop=="profit_point")           check_value = NormalizeDouble(i_profit / (i_volume * SymbolInfoDouble(i_symbol,SYMBOL_TRADE_TICK_VALUE)),0);
        if(position_prop=="profit_point_full")      check_value = NormalizeDouble(i_profit_full / (i_volume * SymbolInfoDouble(i_symbol,SYMBOL_TRADE_TICK_VALUE)),0);
        //--- double props
        if(position_prop=="volume")                 check_value = i_volume;
        if(position_prop=="openprice")              check_value = OrderOpenPrice();
        if(position_prop=="stoploss")               check_value = OrderStopLoss();
        if(position_prop=="takeprofit")             check_value = OrderTakeProfit();
        if(position_prop=="swap")                   check_value = i_swap;
        if(position_prop=="profit")                 check_value = i_profit;
        if(position_prop=="profit_full")            check_value = i_profit_full;

        //---
        if(check_type == "max")
        {
            if(extreme_value == 0 || extreme_value < check_value)
            {
                extreme_value  = check_value;
                extreme_ticket = i_ticket;
            }
        }
        if(check_type == "min")
        {
            if(extreme_value == 0 || extreme_value > check_value)
            {
                extreme_value  = check_value;
                extreme_ticket = i_ticket;
            }
        }
    }
//--- 极值检查结束，返回订单号
    CPosition *posi = new CPosition();
    if(extreme_ticket>0) posi.AssignByTicket(extreme_ticket);
    //---
    return posi;
}


//+------------------------------------------------------------------+
//| 订单组的创建功能                                                |
//+------------------------------------------------------------------+
void PositionGroupCreat(CArrayObj &group,int type,int profit_type,int magic,string comment=NULL,string symbol="current")
{
    if(symbol == "current") symbol = _Symbol;
    int total = OrdersTotal();
//---
    for(int i = 0; i < total; i++)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        //--- parameters of the position
        int    i_ticket = OrderTicket();
        string i_symbol = OrderSymbol();
        //---
        int i_type = OrderType();
        if(type == 0 && i_type != OP_BUY)  continue;
        if(type == 1 && i_type != OP_SELL) continue;
        //---
        if(magic  != 0     && magic  != OrderMagicNumber())  continue;
        if(symbol != "all" && symbol != OrderSymbol())  continue;
        //---
        if(comment != NULL)
        {
            if(StringGetChar(comment,0)=='!')
            {
                string check_comment = StringSubstr(comment,1);
                if(check_comment!=OrderComment()) continue;
            }else if(StringFind(OrderComment(),comment,0)<0) continue;
        }
        //---
        if(profit_type == 0 && OrderProfit() <  0) continue;
        if(profit_type == 1 && OrderProfit() >= 0) continue;
        
        //--- 筛选完毕，开始赋值
        CPosition *posi = new CPosition();
        posi.AssignByTicket(i_ticket);
        group.Add(posi);
    }
    //---
    return;
}


//+------------------------------------------------------------------+
//| 订单组的排序功能                                                |
//+------------------------------------------------------------------+
void PositionGroupSort(CArrayObj &group,string position_prop,int sort_type=0) //sort_type 0=ascend, 1=descend
{
    int number = group.Total();
    for(int i=0;i<number-1;i++)
    {
        for(int j=i+1;j<number;j++)
        {
            CPosition* i_posi = group.At(i);
            CPosition* j_posi = group.At(j);
            //---
            bool exchange = false;
            //---
            if(sort_type==0)
            {
                if(position_prop=="ticket"       &&i_posi.Ticket()      >j_posi.Ticket())       exchange = true;
                if(position_prop=="opentime"     &&i_posi.Opentime()    >j_posi.Opentime())     exchange = true;
                if(position_prop=="openprice"    &&i_posi.Openprice()   >j_posi.Openprice())    exchange = true;
                if(position_prop=="volume"       &&i_posi.Volume()      >j_posi.Volume())       exchange = true;
                if(position_prop=="stoploss"     &&i_posi.Stoploss()    >j_posi.Stoploss())     exchange = true;
                if(position_prop=="takeprofit"   &&i_posi.Takeprofit()  >j_posi.Takeprofit())   exchange = true;
                if(position_prop=="profit"       &&i_posi.Profit()      >j_posi.Profit())       exchange = true;
            }
            if(sort_type==1)
            {
                if(position_prop=="ticket"       &&i_posi.Ticket()      <j_posi.Ticket())       exchange = true;
                if(position_prop=="opentime"     &&i_posi.Opentime()    <j_posi.Opentime())     exchange = true;
                if(position_prop=="openprice"    &&i_posi.Openprice()   <j_posi.Openprice())    exchange = true;
                if(position_prop=="volume"       &&i_posi.Volume()      <j_posi.Volume())       exchange = true;
                if(position_prop=="stoploss"     &&i_posi.Stoploss()    <j_posi.Stoploss())     exchange = true;
                if(position_prop=="takeprofit"   &&i_posi.Takeprofit()  <j_posi.Takeprofit())   exchange = true;
                if(position_prop=="profit"       &&i_posi.Profit()      <j_posi.Profit())       exchange = true;
            }
            //---
            if(exchange==true)
            {
                CPosition* temp = new CPosition();
                temp.AssignByTicket(i_posi.Ticket());
                i_posi.AssignByTicket(j_posi.Ticket());
                j_posi.AssignByTicket(temp.Ticket());
                delete(temp);
            }
        }
    }
    return;
}


//+------------------------------------------------------------------+
//| 价格间隔检查功能                                                |
//+------------------------------------------------------------------+
bool HC_PositionIntervalCheck(string check_type,long interval,int position_type=2,long magic=0,string symbol="current",string comment=NULL)
{
    if(symbol=="current") symbol = _Symbol;
//---
    if(check_type == "any")
    {
        int total = OrdersTotal();
        for(int i = 0; i < total; i++)
        {
            if(OrderSelect(i,SELECT_BY_POS)==false) continue;
            //--- parameters of the position
            ulong  i_ticket = OrderTicket();
            string i_symbol = OrderSymbol();
            double i_point  = SymbolInfoDouble(i_symbol,SYMBOL_POINT);
            //---
            int i_type = OrderType();
            if(i_type>=2) continue;
            if(position_type == 0 && i_type != OP_BUY)  continue;
            if(position_type == 1 && i_type != OP_SELL) continue;
            //---
            if(magic   != 0     && magic   != OrderMagicNumber()) continue;
            if(symbol  != "all" && symbol  != OrderSymbol()) continue;
            //---
            if(comment != NULL)
            {
                if(StringGetChar(comment,0)=='!')
                {
                    string check_comment = StringSubstr(comment,1);
                    if(check_comment!=OrderComment()) continue;
                }else if(StringFind(OrderComment(),comment,0)<0) continue;
            }
            //---
            if(position_type == 0 &&MathAbs(OrderOpenPrice()-SymbolInfoDouble(i_symbol,SYMBOL_ASK))<interval*i_point) return false;
            if(position_type == 1&&MathAbs(OrderOpenPrice()-SymbolInfoDouble(i_symbol,SYMBOL_BID))<interval*i_point) return false;
        }
        return true;
    }
    //---
    double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
    //---
    bool check_res = false;
    //---
    if(check_type == "positive")
    {
        if(position_type == 0)
        {
            CPosition* extreme_posi = HC_Position_Extremum_Check("max","openprice",0,2,symbol,magic,comment);
            if(extreme_posi.Ticket()>0&&SymbolInfoDouble(symbol,SYMBOL_ASK)>extreme_posi.Openprice()+interval*point) check_res = true;
            delete(extreme_posi);
        }
        if(position_type == 1)
        {
            CPosition* extreme_posi = HC_Position_Extremum_Check("min","openprice",1,2,symbol,magic,comment);
            if(extreme_posi.Ticket()>0&&SymbolInfoDouble(symbol,SYMBOL_BID)<extreme_posi.Openprice()-interval*point) check_res = true;
            delete(extreme_posi);
        }
    }
    //---
    if(check_type == "negative")
    {
        if(position_type == 0)
        {
            CPosition* extreme_posi = HC_Position_Extremum_Check("min","openprice",0,2,symbol,magic,comment);
            if(extreme_posi.Ticket()>0&&SymbolInfoDouble(symbol,SYMBOL_ASK)<extreme_posi.Openprice()-interval*point) check_res = true;
            delete(extreme_posi);
        }
        if(position_type == 1)
        {
            CPosition* extreme_posi = HC_Position_Extremum_Check("max","openprice",1,2,symbol,magic,comment);
            if(extreme_posi.Ticket()>0&&SymbolInfoDouble(symbol,SYMBOL_BID)>extreme_posi.Openprice()+interval*point) check_res = true;
            delete(extreme_posi);
        }
    }
    //---
    return check_res;
}


//+------------------------------------------------------------------+
//| 时间间隔检查功能                                                |
//+------------------------------------------------------------------+
bool HC_PositionIntervalTimeCheck(long seconds,int position_type = 2,long magic = 0,string symbol = "current",string comment = NULL)
{
    if(symbol=="current") symbol = _Symbol;
    //---
    bool check_res = false;
    CPosition* extreme_posi = HC_Position_Extremum_Check("max","opentime",position_type,2,symbol,magic,comment);
    if(extreme_posi.Ticket()>0&&TimeCurrent()-extreme_posi.Opentime()>seconds) check_res = true;
    delete(extreme_posi);
    //---
    return check_res;
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------------------------------------------------------------------------+
void HC_BreakEven_for_EverySinglePosition(int type,int trigger_point,int sl_profit_point,int magic=0,string symbol="current",string comment=NULL)        // 多个订单，相互独立保本止损功能
//+------------------------------------------------------------------------------------------------------------------------------------+
{
    if(symbol=="current") symbol = Symbol();  //当不指定商品时，Symb 设为当前图表商品。
    int pos_num = OrdersTotal();
    for(int i=0;i<pos_num;i++)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        ulong i_ticket = OrderTicket();
        if(i_ticket>0)
        {
            //复测是否符合条件
            if(magic>0&&OrderMagicNumber()!=magic) continue;
            string i_symbol = OrderSymbol();
            if(symbol!="all"&&i_symbol!=symbol) continue;  
            //---
            if(comment != NULL)
            {
                if(StringGetChar(comment,0)=='!')
                {
                    if(comment!=OrderComment()) continue;
                }else if(StringFind(OrderComment(),comment,0)<0) continue;
            }
            //全部条件符合后 收录数据
            int    i_type       = OrderType();
            double i_sl         = OrderStopLoss();
            double i_open_price = OrderOpenPrice();
            double i_point      = SymbolInfoDouble(i_symbol,SYMBOL_POINT);
            //---
            double i_ask = SymbolInfoDouble(i_symbol,SYMBOL_ASK);
            double i_bid = SymbolInfoDouble(i_symbol,SYMBOL_BID);
            //---
            if(type==2||(type==0&&i_type==OP_BUY)||(type==1&&i_type==OP_SELL))
            {
                if(i_type==OP_BUY)
                {
                    if(i_sl>0&&i_sl>=i_open_price+sl_profit_point*i_point) continue;
                    if(trigger_point>0&&i_bid>i_open_price+trigger_point*i_point)
                    {
                        HC_PositionModify(i_ticket,i_open_price+sl_profit_point*i_point,-1);
                    }
                }
                if(i_type==OP_SELL)
                {
                    if(i_sl>0&&i_sl<=i_open_price-sl_profit_point*i_point) continue;
                    if(trigger_point>0&&i_ask<i_open_price-trigger_point*i_point)
                    {
                        HC_PositionModify(i_ticket,i_open_price-sl_profit_point*i_point,-1);
                    }
                }
            }
        }
    }
    return;
}


void HC_TrailingStop_for_EverySinglePosition(int type,int trigger_point,int sl_profit_point,int step,int magic=0,string symbol="current",string comment=NULL)        // 触发模式
//+------------------------------------------------------------------------------------------------------------------------------------+
{
    if(symbol=="current") symbol = Symbol();  //当不指定商品时，Symb 设为当前图表商品。
    int pos_num = OrdersTotal();
    for(int i=0;i<pos_num;i++)
    {
        if(OrderSelect(i,SELECT_BY_POS)==false) continue;
        ulong i_ticket = OrderTicket();
        if(i_ticket>0)
        {
            //复测是否符合条件
            if(magic>0&&OrderMagicNumber()!=magic) continue;
            string i_symbol = OrderSymbol();
            if(symbol!="all"&&i_symbol!=symbol) continue;
            //---
            if(comment != NULL)
            {
                if(StringGetChar(comment,0)=='!')
                {
                    if(comment!=OrderComment()) continue;
                }else if(StringFind(OrderComment(),comment,0)<0) continue;
            }
            //全部条件符合后 收录数据
            int    i_type       = OrderType();
            double i_sl         = OrderStopLoss();
            double i_open_price = OrderOpenPrice();
            double i_point      = SymbolInfoDouble(i_symbol,SYMBOL_POINT);
            //---
            double i_ask = SymbolInfoDouble(i_symbol,SYMBOL_ASK);
            double i_bid = SymbolInfoDouble(i_symbol,SYMBOL_BID);
            //---
            int space_point = trigger_point-sl_profit_point;
            //---
            if(type==2||(type==0&&i_type==OP_BUY)||(type==1&&i_type==OP_SELL))
            {
                if(i_type==OP_BUY)
                {
                    if((i_sl==0||i_sl<i_open_price+sl_profit_point*i_point+i_point)&&trigger_point>0)
                    {
                        string line_name = "hc_tsl_trigger_buy_"+string(i_ticket);
                        if(ObjectFind(0,line_name)<0) HLineCreate(line_name,0,i_open_price+trigger_point*i_point,1,clrOrange,STYLE_SOLID);
                        //---
                        if(i_bid>i_open_price+trigger_point*i_point)
                        {
                            HC_PositionModify(i_ticket,i_open_price+sl_profit_point*i_point,-1);  //第一次触发
                            ObjectDelete(0,line_name);
                        }
                    }
                    if(i_sl>0&&i_sl>=i_open_price+sl_profit_point*i_point-i_point&&i_bid>i_sl+(space_point+step)*i_point) HC_PositionModify(i_ticket,i_bid-(space_point+step)*i_point,-1);
                }
                if(i_type==OP_SELL)
                {
                    if((i_sl==0||i_sl>i_open_price-sl_profit_point*i_point-i_point)&&trigger_point>0)
                    {
                        string line_name = "hc_tsl_trigger_sell_"+string(i_ticket);
                        if(ObjectFind(0,line_name)<0) HLineCreate(line_name,0,i_open_price-trigger_point*i_point,1,clrAqua,STYLE_SOLID);
                        //---
                        if(i_bid<i_open_price-trigger_point*i_point)
                        {
                            HC_PositionModify(i_ticket,i_open_price-sl_profit_point*i_point,-1);  //第一次触发
                            ObjectDelete(0,line_name);
                        }
                    }
                    if(i_sl>0&&i_sl<=i_open_price-sl_profit_point*i_point+i_point&&i_ask<i_sl-(space_point+step)*i_point) HC_PositionModify(i_ticket,i_ask+(space_point+step)*i_point,-1);
                }
            }
        }
    }
    //--- 检查 并 删除 多余线
    for(int i=0;i<ObjectsTotal();i++)
    {
        string i_name = ObjectName(0,i);
        int check_ticket = -1;
        if(StringFind(i_name,"hc_tsl_trigger_buy_")==0) //表示找到
        {
            check_ticket = (int)StringSubstr(i_name,StringLen("hc_tsl_trigger_buy_"));
        }
        if(StringFind(i_name,"hc_tsl_trigger_sell_")==0) //表示找到
        {
            check_ticket = (int)StringSubstr(i_name,StringLen("hc_tsl_trigger_sell_"));
        }
        //---
        if(check_ticket>=0)
        {
            if(OrderSelect(check_ticket,SELECT_BY_TICKET))
            {
                if(OrderCloseTime()>0) ObjectDelete(i_name);
            }else ObjectDelete(i_name);
        }
    }
    //---
    return;
}


//+------------------------------------------------------------------+
//| Create the horizontal line                                       |
//+------------------------------------------------------------------+
bool HLineCreate(const string          name="HLine",      // line name
                 const int             sub_window=0,      // subwindow index
                 double                price=0,           // line price
                 const int             width=1,           // line width
                 const color           clr=clrRed,        // line color
                 const ENUM_LINE_STYLE style=STYLE_SOLID, // line style
                 //---
                 const long            chart_ID=0,        // chart's ID
                 const bool            back=false,        // in the background
                 const bool            selection=false,    // highlight to move
                 const bool            hidden=true,       // hidden in the object list
                 const long            z_order=0)         // priority for mouse click
{
//--- if the price is not set, set it at the current Bid price level
    //if(!price)
    //    price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- reset the error value
    ResetLastError();
//--- create a horizontal line
    if(!ObjectCreate(chart_ID,name,OBJ_HLINE,sub_window,0,price))
    {
        int error_code = GetLastError();
        if(error_code!=4200)
        {
            Print(__FUNCTION__,": failed to create a horizontal line! Error code = ",error_code);
            return(false);
        }
    }
//--- set line price
    ObjectSetDouble(chart_ID,name,OBJPROP_PRICE,price);
//--- set line color
    ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set line display style
    ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set line width
    ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- display in the foreground (false) or background (true)
    ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the line by mouse
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
    ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
    ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
    ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
    ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
    return(true);
}

//+------------------------------------------------------------------+ 
//| Create Buy sign                                                  | 
//+------------------------------------------------------------------+ 
bool ArrowBuyCreate(const long            chart_ID=0,        // chart's ID 
                    const string          name="ArrowBuy",   // sign name 
                    const int             sub_window=0,      // subwindow index 
                    datetime              time=0,            // anchor point time 
                    double                price=0,           // anchor point price 
                    const color           clr=C'3,95,172',   // sign color 
                    const ENUM_LINE_STYLE style=STYLE_SOLID, // line style (when highlighted) 
                    const int             width=1,           // line size (when highlighted) 
                    const bool            back=false,        // in the background 
                    const bool            selection=false,   // highlight to move 
                    const bool            hidden=true,       // hidden in the object list 
                    const long            z_order=0)         // priority for mouse click 
  { 
//--- set anchor point coordinates if they are not set 
   ChangeArrowEmptyPoint(time,price); 
//--- reset the error value 
   ResetLastError(); 
//--- create the sign 
   if(!ObjectCreate(chart_ID,name,OBJ_ARROW_BUY,sub_window,time,price)) 
     { 
      Print(__FUNCTION__, 
            ": failed to create \"Buy\" sign! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- set a sign color 
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr); 
//--- set a line style (when highlighted) 
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style); 
//--- set a line size (when highlighted) 
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width); 
//--- display in the foreground (false) or background (true) 
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
//--- enable (true) or disable (false) the mode of moving the sign by mouse 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection); 
//--- hide (true) or display (false) graphical object name in the object list 
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
//--- set the priority for receiving the event of a mouse click in the chart 
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order); 
//--- successful execution 
   return(true); 
  } 
//+------------------------------------------------------------------+ 
//| Move the anchor point                                            | 
//+------------------------------------------------------------------+ 
bool ArrowBuyMove(const long   chart_ID=0,      // chart's ID 
                  const string name="ArrowBuy", // object name 
                  datetime     time=0,          // anchor point time coordinate 
                  double       price=0)         // anchor point price coordinate 
  { 
//--- if point position is not set, move it to the current bar having Bid price 
   if(!time) 
      time=TimeCurrent(); 
   if(!price) 
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID); 
//--- reset the error value 
   ResetLastError(); 
//--- move the anchor point 
   if(!ObjectMove(chart_ID,name,0,time,price)) 
     { 
      Print(__FUNCTION__, 
            ": failed to move the anchor point! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- successful execution 
   return(true); 
  } 
//+------------------------------------------------------------------+ 
//| Delete Buy sign                                                  | 
//+------------------------------------------------------------------+ 
bool ArrowBuyDelete(const long   chart_ID=0,      // chart's ID 
                    const string name="ArrowBuy") // sign name 
  { 
//--- reset the error value 
   ResetLastError(); 
//--- delete the sign 
   if(!ObjectDelete(chart_ID,name)) 
     { 
      Print(__FUNCTION__, 
            ": failed to delete \"Buy\" sign! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- successful execution 
   return(true); 
  } 
//+------------------------------------------------------------------+ 
//| Check anchor point values and set default values                 | 
//| for empty ones                                                   | 
//+------------------------------------------------------------------+ 
void ChangeArrowEmptyPoint(datetime &time,double &price) 
  { 
//--- if the point's time is not set, it will be on the current bar 
   if(!time) 
      time=TimeCurrent(); 
//--- if the point's price is not set, it will have Bid value 
   if(!price) 
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID); 
  } 
  
  //+------------------------------------------------------------------+ 
//| Create Sell sign                                                 | 
//+------------------------------------------------------------------+ 
bool ArrowSellCreate(const long            chart_ID=0,        // chart's ID 
                     const string          name="ArrowSell",  // sign name 
                     const int             sub_window=0,      // subwindow index 
                     datetime              time=0,            // anchor point time 
                     double                price=0,           // anchor point price 
                     const color           clr=C'225,68,29',  // sign color 
                     const ENUM_LINE_STYLE style=STYLE_SOLID, // line style (when highlighted) 
                     const int             width=1,           // line size (when highlighted) 
                     const bool            back=false,        // in the background 
                     const bool            selection=false,   // highlight to move 
                     const bool            hidden=true,       // hidden in the object list 
                     const long            z_order=0)         // priority for mouse click 
  { 
//--- set anchor point coordinates if they are not set 
   ChangeArrowEmptyPoint(time,price); 
//--- reset the error value 
   ResetLastError(); 
//--- create the sign 
   if(!ObjectCreate(chart_ID,name,OBJ_ARROW_SELL,sub_window,time,price)) 
     { 
      Print(__FUNCTION__, 
            ": failed to create \"Sell\" sign! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- set a sign color 
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr); 
//--- set a line style (when highlighted) 
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style); 
//--- set a line size (when highlighted) 
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width); 
//--- display in the foreground (false) or background (true) 
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back); 
//--- enable (true) or disable (false) the mode of moving the sign by mouse 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection); 
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection); 
//--- hide (true) or display (false) graphical object name in the object list 
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden); 
//--- set the priority for receiving the event of a mouse click in the chart 
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order); 
//--- successful execution 
   return(true); 
  } 
//+------------------------------------------------------------------+ 
//| Move the anchor point                                            | 
//+------------------------------------------------------------------+ 
bool ArrowSellMove(const long   chart_ID=0,       // chart's ID 
                   const string name="ArrowSell", // object name 
                   datetime     time=0,           // anchor point time coordinate 
                   double       price=0)          // anchor point price coordinate 
  { 
//--- if point position is not set, move it to the current bar having Bid price 
   if(!time) 
      time=TimeCurrent(); 
   if(!price) 
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID); 
//--- reset the error value 
   ResetLastError(); 
//--- move the anchor point 
   if(!ObjectMove(chart_ID,name,0,time,price)) 
     { 
      Print(__FUNCTION__, 
            ": failed to move the anchor point! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- successful execution 
   return(true); 
  } 
//+------------------------------------------------------------------+ 
//| Delete Sell sign                                                 | 
//+------------------------------------------------------------------+ 
bool ArrowSellDelete(const long   chart_ID=0,       // chart's ID 
                     const string name="ArrowSell") // sign name 
  { 
//--- reset the error value 
   ResetLastError(); 
//--- delete the sign 
   if(!ObjectDelete(chart_ID,name)) 
     { 
      Print(__FUNCTION__, 
            ": failed to delete \"Sell\" sign! Error code = ",GetLastError()); 
      return(false); 
     } 
//--- successful execution 
   return(true); 
  } 
  

//+------------------------------------------------------------------+
//| Create the arrow                                                 |
//+------------------------------------------------------------------+
bool ArrowCreate(const string            name="Arrow",         // arrow name
                 const int               sub_window=0,         // subwindow index
                 datetime                time=0,               // anchor point time
                 double                  price=0,              // anchor point price
                 const int               width=3,              // arrow size
                 const color             clr=clrRed,           // arrow color
                 //---
                 const uchar             arrow_code=252,       // arrow code
                 const ENUM_ARROW_ANCHOR anchor=ANCHOR_BOTTOM, // anchor point position
                 const ENUM_LINE_STYLE   style=STYLE_SOLID,    // border line style
                 //--- 
                 const long              chart_ID=0,           // chart's ID
                 const bool              back=false,           // in the background
                 const bool              selection=false,       // highlight to move
                 const bool              hidden=true,          // hidden in the object list
                 const long              z_order=0)            // priority for mouse click
{
//--- set anchor point coordinates if they are not set
    ChangeArrowEmptyPoint(time,price);
//--- reset the error value
    ResetLastError();
//--- create an arrow
    if(!ObjectCreate(chart_ID,name,OBJ_ARROW,sub_window,time,price))
    {
        int error_code = GetLastError();
        if(error_code!=4200)
        {
            Print(__FUNCTION__,": failed to create arrow object! Error code = ",GetLastError());
            return(false);
        }
    }
//--- set the arrow code
    ObjectSetInteger(chart_ID,name,OBJPROP_ARROWCODE,arrow_code);
//--- set anchor type
    ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,anchor);
//--- set the arrow color
    ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set the border line style
    ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set the arrow's size
    ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- display in the foreground (false) or background (true)
    ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the arrow by mouse
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
    ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
    ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
    ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
    ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
    return(true);
}



