//+------------------------------------------------------------------+
//|                                                   IncredocqB.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

string nomIndice = "GER30"; //sovrascritto dopo in init()

extern int SIGNATURE = 0021000;
extern string COMMENT = "TrendFollower";
extern double POWER = 20; 


int actualOrders = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   nomIndice = Symbol();
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()



  {
//---
   // ===============
   // Buy conditions
   // ===============
   if (
      (isUpTrend())
      && (isMin())
      ) openOrder(OP_BUY, POWER);
      
   // ===============
   // Sell conditions
   // ===============
   if (
      (isDownTrend())
      && (isMin())
      ) openOrder(OP_SELL, POWER);
      
   
   //if (closeBuyConditions()) closeBuy();
   
  }
//+------------------------------------------------------------------+


//-------------------------------------------------+
//    Sono in un trend UP 
//-------------------------------------------------+
bool isUpTrend(){
   double fastMA = iMA(nomIndice,PERIOD_CURRENT,7,0,MODE_EMA,PRICE_MEDIAN,1);
   double slowMA = iMA(nomIndice,PERIOD_CURRENT,21,0,MODE_SMMA,PRICE_MEDIAN,1);
   
   if (fastMA > slowMA) return true;
   else return false;
}

//-------------------------------------------------+
//    Sono in un trend DOWN 
//-------------------------------------------------+
bool isDownTrend(){
   double fastMA = iMA(nomIndice,PERIOD_CURRENT,7,0,MODE_EMA,PRICE_MEDIAN,1);
   double slowMA = iMA(nomIndice,PERIOD_CURRENT,21,0,MODE_SMMA,PRICE_MEDIAN,1);
   
   if (fastMA < slowMA) return true;
   else return false;
}

//-------------------------------------------------+
//    Ho appena passato un minimo assoluto 
//-------------------------------------------------+
bool isMin(){

   double nearMin, farMin;
   int shift;
   
   shift = 1;
   nearMin = Low[shift]; 
   
   shift = iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,10,2);
   farMin = Low[shift];

   if (nearMin < farMin) return true;

   else return false;

}

//-------------------------------------------------+
//    Sono su un massimo assoluto 
//-------------------------------------------------+
bool isMax(){

   double nearMax, farMax;
   int shift;
   
   shift = 1;
   nearMax = High[shift]; 
   
   shift = iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,10,2);
   farMax = High[shift];
 
   if (nearMax > farMax) return true;
  
   else return false;

}


bool openOrder(int ot, double sz){
   int ticket = -1;
   double tp = 0, sl = 0, prz =0;
   color c;
   if (ot == OP_BUY) {prz = MarketInfo(nomIndice,MODE_ASK); tp = prz+((prz-Low[1])*3); sl = Low[1]-2*Point; c = clrBlue;}
   if (ot == OP_SELL){prz = MarketInfo(nomIndice,MODE_BID); tp = prz-((High[1]-prz)*3); sl = High[1]+2*Point; c=clrRed; }

   
   while(ticket<0){
      ticket = OrderSend(nomIndice,ot,sz,prz,2,sl,tp,COMMENT ,SIGNATURE,0,c);
   }

   return true;
}