//+------------------------------------------------------------------+
//|                                                   IncredocqB.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Y3"
#property link      "https://www.y3web.it"
#property version   "1.00"
#property strict
// ============== NOTE ======================
// GBP USD (2015) sarStep 0.015 > performance belle stabili
// GER30 Ago-Dic 2015 sarSpet 0.01 - partialCloseEnabled=true - trendFilter=3 [isUpTrend(3)] > miglior sfruttamento dei trend
// EURUSD - ToDo


string bot_name = "Maxx";
string nomIndice = "GER30"; //sovrascritto dopo in init()

extern int SIGNATURE = 0077330;
extern string COMMENT = "Y3_Maxx";
extern double POWER = 20;
extern double maxAdmittedLots = 60;
extern bool partialCloseEnabled = true;
extern double tpMultiplier = 3.0;
extern bool useAMA_Filter = true;
extern int startingHour = 8;
extern int endingHour = 23;
int MinMax_distance = 10;

// ----- enter conditions array -----
bool buyConditions[5]; 
bool sellConditions[5]; 


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
   // close spare pending protections
   //closeSparePendingOrders();
   
   // alle 21:00 chiudo comunque tutto, aperti e pendenti
   //timeToCloseAll();


   //-------------------------------------------------+
   //   il profitto totale di tutto � positivo
   //-------------------------------------------------+
  //if(   (averageAllIsPositive())          
  //   )   {
  //       closeAllBuyOrders();
   //      closeAllSellOrders();
   //      closeSparePendingOrders();
   //  }      
     

   // ===============
   // Buy conditions
   // ===============
   /*
   ArrayInitialize(buyConditions,false);   //Array buyConditions per debuggare

   if (isUpTrend(3))                         buyConditions[0] = true; 
   if (isMin())                              buyConditions[1] = true; 
   if (maxIsBroken())                        buyConditions[2] = true; 
   if (!existOpendedAndClosedOnThisBar(1))   buyConditions[3] = true; 
   if (!existOrderOnThisBar(OP_BUY))         buyConditions[4] = true; 

   
   if(   (buyConditions[0]) 
      && (buyConditions[1]) 
      && (buyConditions[2]) 
      && (buyConditions[3])
      && (buyConditions[4])
     )   
         openOrder(OP_BUY, POWER);
   */
   
   if(   (isUpSignal())
      //&& (!oddOrders())
      && (isUpAMA())
      //&& (averageSellIsPositive())
      && (TimeHour(TimeCurrent()) >= startingHour)
      && (TimeHour(TimeCurrent()) < endingHour)
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_BUY))
      && (!existOrder(OP_BUY))
     )   {
         //closeAllSellOrders();
         //closeSparePendingOrders();
         openOrder(OP_BUY, POWER);
     }

/*
   //---------------------------------------+
   //   chiusura con segnale di inversione
   //---------------------------------------+
   if(   (isDownSignal())
      && (isDownAMA())
      && (oddOrders())
      && (averageBuyIsPositive())          
     )   {
         closeAllBuyOrders();
         closeSparePendingOrders();
     }      
    

   //---------------------------------------+
   //   chiusura di emergenza 1
   //---------------------------------------+
   if(   (tooMuchLots(OP_BUY))
      && (isDownSignal())
      && (isDownAMA())   
     )   {
         convertOrderToProtection(OP_BUY);
         closeAllBuyOrders();
         closeSparePendingOrders();
     }      
*/

      // --- chiusura parziale ---
      //if (minGainReached(OrderTicket()))
      //   partialClose(OrderTicket());


      
   // ===============
   // Sell conditions
   // ===============
   /*
   ArrayInitialize(sellConditions,false);  //Array sellConditions per debuggare
   
   if (isDownTrend(3))                       sellConditions[0] = true;
   if (isMax())                              sellConditions[1] = true;
   if (minIsBroken())                        sellConditions[2] = true;
   if (!existOpendedAndClosedOnThisBar(1))   sellConditions[3] = true;
   if (!existOrderOnThisBar(OP_SELL))        sellConditions[4] = true;
      
      
      
   if(   (sellConditions[0]) 
      && (sellConditions[1]) 
      && (sellConditions[2]) 
      && (sellConditions[3])
      && (sellConditions[4])
     )   
         openOrder(OP_SELL, POWER);
   */
   
   if(   (isDownSignal())
      //&& (!oddOrders())
      && (isDownAMA())
      //&& (averageBuyIsPositive())
      && (TimeHour(TimeCurrent()) >= startingHour)
      && (TimeHour(TimeCurrent()) < endingHour)      
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_SELL))
      && (!existOrder(OP_SELL))
     )   {
         //closeAllBuyOrders();
         //closeSparePendingOrders();
         openOrder(OP_SELL, POWER);
     }
/*   
   //---------------------------------------+
   //   chiusura con segnale di inversione
   //---------------------------------------+
   if(   (isUpSignal())
      && (isUpAMA())
      && (oddOrders())
      && (averageSellIsPositive())          
     )   {
         closeAllSellOrders();
         closeSparePendingOrders();
     }

   //---------------------------------------+
   //   chiusura di emergenza 1
   //---------------------------------------+
   if(   (tooMuchLots(OP_SELL))
      && (isUpSignal())
      && (isUpAMA())   
     )   {
         convertOrderToProtection(OP_SELL);
         closeAllSellOrders();
         closeSparePendingOrders();
     }      
*/
   
   // screen Log
   //screenLog();
   
}
//+------------------------------------------------------------------+
//+----------------      OnTick End     -----------------------------+
//+------------------------------------------------------------------+


//----------------------------------------------------------------+
//    Si verifica una barra di colore opposto e la si sfonda UP
//----------------------------------------------------------------+
bool isUpSignal(){
      
   string lastBarDirection = "up";
   string prevBarDirection = "up";
   double lastBarSize = MathAbs(High[1]-Low[1]);
   double prevBarSize = MathAbs(High[2]-Low[2]);
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   bool result = false;
   
   if( Open[1]>Close[1] ) lastBarDirection = "down";
   if( Open[2]>Close[2] ) prevBarDirection = "down";

   
   if( (lastBarDirection == "up") && (prevBarDirection == "down") && (lastBarSize > prevBarSize) && (actualPrice > High[1]) ) result = true;
   // TODO: aggiungere qui sopra anche le condizioni sulla dimensione delle barre (vola)
   
   return result;
   
}


//----------------------------------------------------------------+
//    Si verifica una barra di colore opposto e la si sfonda DOWN
//----------------------------------------------------------------+
bool isDownSignal(){

   string lastBarDirection = "up";
   string prevBarDirection = "up";
   double lastBarSize = MathAbs(High[1]-Low[1]);
   double prevBarSize = MathAbs(High[2]-Low[2]);
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   bool result = false;
   
   if( Open[1]>Close[1] ) lastBarDirection = "down";
   if( Open[2]>Close[2] ) prevBarDirection = "down";

   
   if( (lastBarDirection == "down") && (prevBarDirection == "up") && (lastBarSize > prevBarSize) && (actualPrice < Low[1]) ) result = true;
   // TODO: aggiungere qui sopra anche le condizioni sulla dimensione delle barre (vola)
   
   return result;
   
}



//-------------------------------------------------+
//    L'AMA � up
//-------------------------------------------------+
bool isUpAMA(){
   if (!useAMA_Filter) return true;
   
   double lastAMA = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,1,1);
   bool result = false;
   
   if(lastAMA > 0) result = true;
   return result;
   
}


//-------------------------------------------------+
//    L'AMA � down 
//-------------------------------------------------+
bool isDownAMA(){
   if (!useAMA_Filter) return true;
   
   double lastAMA = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,2,1);
   bool result = false;
   
   if (lastAMA > 0)  result = true;
   return result;
   
}

//-------------------------------------------------+
//    Ordini Buy e Sell Dispari 
//   true = gli ordini sono dispari (non sono entrate le protezioni)
//   false = tutti gli ordini sono edgiati
//-------------------------------------------------+
bool oddOrders(){
   int total = OrdersTotal();
   double buyLots = 0;
   double sellLots = 0;
   bool result = true;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY)  && (OrderCloseTime() == 0) ) buyLots += OrderLots();
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0) ) sellLots += OrderLots();
   }
   buyLots = NormalizeDouble(buyLots,2);
   sellLots = NormalizeDouble(sellLots,2);
   
   if (buyLots == sellLots) result=false;
   
   
   return result;       

}



//-------------------------------------------------------+
//    La media di tutti gli ordini attivi � in profitto 
//-------------------------------------------------------+
bool averageAllIsPositive(){
   int total = OrdersTotal();
   int numberOfOrders = 0;
   double orderProfit = 0;
   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_BUY) || (OrderType() == OP_SELL) )  && (OrderCloseTime() == 0) ){
         numberOfOrders++;
         orderProfit += OrderProfit();
      }
      
   }

   if ( (orderProfit > 0) && (numberOfOrders > 1)) result = true;
   
   return result;
}


//-------------------------------------------------+
//    La media dei buy attivi � in profitto 
//-------------------------------------------------+
bool averageBuyIsPositive(){
   int total = OrdersTotal();
   int numberOfOrders = 0;
   double orderProfit = 0;
   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY)  && (OrderCloseTime() == 0) ){
         numberOfOrders++;
         orderProfit += OrderProfit();
      }
      
   }

   if ( (orderProfit > 0) || (numberOfOrders == 0)) result = true;
   
   return result;
}

//-------------------------------------------------+
//    La media dei sell attivi � in profitto 
//-------------------------------------------------+
bool averageSellIsPositive(){
   int total = OrdersTotal();
   int numberOfOrders = 0;
   double orderProfit = 0;
   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL)  && (OrderCloseTime() == 0) ){
         numberOfOrders++;
         orderProfit += OrderProfit();
      }     
   }
   
   if ( (orderProfit > 0) || (numberOfOrders == 0)) result = true;

   return result;
}


//-------------------------------------------------+
//    verifica se ci sono troppi lotti aperti  
//-------------------------------------------------+
bool tooMuchLots(int ot){
   int total = OrdersTotal();
   int openLots = 0;

   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == ot)  && (OrderCloseTime() == 0) ){
         openLots += OrderLots();
      }     
   }
   
   if ( openLots >= maxAdmittedLots ) result = true;

   return result;
}


//---------------------------------------------------+
//    Chiude gli ordini pending rimasti soli 
//---------------------------------------------------+
bool closeSparePendingOrders(){
   int total = OrdersTotal();
   int openOrders = 0;
   double pendingOrders = 0;
   bool result = true;
   
   for(int pos=0;pos<total;pos++)
   {    
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_BUY) || ((OrderType() == OP_SELL)))  && (OrderCloseTime() == 0) ) openOrders++;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_BUYSTOP) || ((OrderType() == OP_SELLSTOP))) && (OrderCloseTime() == 0) ) pendingOrders++;
   }
   
   if ((openOrders == 0) && (pendingOrders > 0)) 
   for(int pos=0;pos<total;pos++)
   {    
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_BUYSTOP) || ((OrderType() == OP_SELLSTOP))) && (OrderCloseTime() == 0) )  {
         OrderDelete(OrderTicket());
      }
   }
   
   return result;       
}


//-------------------------------------------------+
//    Aggiungo un segno nel punto di ingresso 
//-------------------------------------------------+
bool drawNewEntryPoint(int ot, double targetPrice){
   string objName = "BuyPoint"+(string)Time[0];
   int arrowCode = 4;
   color c = C'250,255,30';
   if (ot==OP_SELL) {objName="SellPoint"+(string)Time[0]; arrowCode = 4; c = C'255,80,80';}
   
   
   if(ObjectFind(0,objName) < 0) 
   {
      ObjectCreate(0,objName,OBJ_ARROW,0,Time[0],targetPrice);
      ObjectSet(objName,OBJPROP_ARROWCODE,arrowCode);
      ObjectSet(objName,OBJPROP_COLOR,c);
   }
   
   return false;
}



//-------------------------------------------------+
//    Ho rotto il max precedente 
//-------------------------------------------------+
bool maxIsBroken(){
   int shift = iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,3,1); // il max precedente � quello della barra col minimo locale
   double localMax = High[shift];
   double nextMax = High[iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,shift,1)]; //massimo delle barre da 1 alla barra del minimo locale
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   
   if ((actualPrice > localMax) && (nextMax <= localMax)) return true;
   else return false;
   
}

//-------------------------------------------------+
//    Ho rotto il min precedente 
//-------------------------------------------------+
bool minIsBroken(){
   int shift = iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,3,1); // il min precedente � quello della barra col massimo locale
   double localMin = Low[shift];
   double nextMin = Low[iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,shift,1)]; //minimo delle barre da 1 alla barra del massimo locale
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   
   if ((actualPrice < localMin) && (nextMin >= localMin)) return true;
   else return false;
   
}


//-------------------------------------------------+
//    Ho appena passato un minimo locale 
//-------------------------------------------------+
bool isMin(){

   double nearMin, farMin;
   int nearShift, farShift;
   
   nearShift = iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,3,1); //posizione del minimo delle ultime tre barre partendo dalla 1
   nearMin = Low[nearShift]; // valore del minimo delle ultime 3 barre partendo dalla 1
   
   farShift = iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,MinMax_distance,nearShift+1); // minimo delle MinMax_distance barre partendo da quella successiva al minimo near
   farMin = Low[farShift]; // suo valore
   
   
   //if ((nearMin < farMin)  )return true; // senza guardare i minimi decrescenti
   if ((nearMin < farMin) && (High[1] <= High[2]) )return true;  // guardando i minimi decrescenti (migliora P.F e R.A.)

   else return false;

}

//-------------------------------------------------+
//    Sono su un massimo locale 
//-------------------------------------------------+
bool isMax(){

   double nearMax, farMax;
   int nearShift, farShift;
   
   nearShift = iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,3,1); //posizione del massimo delle ultime tre barre partendo dalla 1
   nearMax = High[nearShift];  // valore del massimo delle ultime 3 barre partendo dalla 1
   
   farShift = iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,MinMax_distance,nearShift+1); // massimo delle MinMax_distance barre partendo da quella precedente al massimo near
   farMax = High[farShift]; // suo valore
 
   //if ((nearMax > farMax)  ) return true; // senza guardare i massimi crescenti
   if ((nearMax > farMax) && (Low[1] >= Low[2]) ) return true; // guardando i massimi crescenti (migliora P.F e R.A.)
  
   else return false;

}


//-------------------------------------------------+
//    Ho gi� un ordine aperto in questa barra? 
//-------------------------------------------------+
bool existOrderOnThisBar(int ot) 
{
   bool result = false;
   
   int total = OrdersTotal();
   
   for(int pos=0;pos<total;pos++)
   {
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY) && (OrderCloseTime() == 0) && (ot == OP_BUY) && (iBarShift(nomIndice,0,OrderOpenTime(),false) == 0) )         
         return true;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0)&& (ot == OP_SELL)  && (iBarShift(nomIndice,0,OrderOpenTime(),false)== 0) )         
         return true;
   }
   
   return result;    
   
}
   
//--------------------------------------------------------+
//    Ho gi� n ordini aperti e chiusi in questa barra? 
//--------------------------------------------------------+
bool existOpendedAndClosedOnThisBar(int limit) 
{
   bool result = false;
   
   int total = OrdersTotal();
   int o = 0;
   
   for (int i=OrdersHistoryTotal()-1; i>=0; i--)
   {
      if ( (OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true) && (OrderMagicNumber()==SIGNATURE) && (OrderSymbol()==nomIndice) && (iBarShift(nomIndice,0,OrderOpenTime(),false) == 0) && (iBarShift(nomIndice,0,OrderCloseTime(),false) == 0))         
      {
         o = o+1;        
         if (o >= limit) {result = true; break;}
      }
   }
   
   return result;    
   
}   

//-----------------------------------------------------------------+
//       Eiste gi� un ordine aperto  
//-----------------------------------------------------------------+
bool existOrder(int ot) 
{
   int total = OrdersTotal();
   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      /* verifica esistenza di ordini buy o ordini sell
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY) && (OrderCloseTime() == 0) && (ot == OP_BUY) )         
         result = true;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0) && (ot == OP_SELL) )         
         result = true;
      */
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_BUY) || (OrderType() == OP_SELL)) && (OrderCloseTime() == 0) )
          {result = true;}
   }
   
   return result;       
}


//--------------------------------------------------------+
//                Apertura di un ordine 
//--------------------------------------------------------+
bool openOrder(int ot, double sz){
   int ticket = -1;
   double tp = 0, sl = 0, prz =0;
   color c = clrBlue;
   double spread = MarketInfo(nomIndice,MODE_SPREAD);
   if (ot == OP_BUY) {  prz = MarketInfo(nomIndice,MODE_ASK); 
                        sl = Low[iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,10,1)]-spread*Point; 
                        tp=NormalizeDouble(prz+tpMultiplier*MathAbs(prz-sl),Digits);  c = clrBlue;
                        sl = prz - 1000*Point;
                        tp = prz + 1000*tpMultiplier*Point;                        
                     }
   if (ot == OP_SELL){  prz = MarketInfo(nomIndice,MODE_BID); 
                        sl = High[iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,10,1)]+2*spread*Point; 
                        tp=NormalizeDouble(prz-tpMultiplier*MathAbs(prz-sl),Digits); c = clrRed; 
                        sl = prz + 1000*Point;
                        tp = prz - 1000*tpMultiplier*Point;
                     }

   //sz = getSize(2,MathAbs(tp-sl)/Point);
   double protectionPrice = sl;
   //sl = 0;
   //tp = 0;
   sz = Martin(sz);
   ticket = OrderSend(nomIndice,ot,sz,prz,2,sl,tp,COMMENT ,SIGNATURE,0,c);
   
   //sposto il tp di tutti gli ordini di questi tipo sul nuovo valore
   //moveTakeProfit(ot, tp);
   
   // piazzo la copertura
   //placeProtection(ot, protectionPrice, sz);

   return true;
}

//--------------------------------------------------------+
//             Martingalone 
//--------------------------------------------------------+
double Martin(double sz){
   int total = OrdersTotal();
   double newSize = sz;
   bool alreadyOpened = false;
   // c'� gi� un ordine aperto con size > sz?   
   for(int pos=0;pos<total;pos++)
   {      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_SELL) || (OrderType() == OP_BUY)) && (OrderCloseTime() == 0) ){
         if (OrderLots() > sz) return sz;
      }
   }
   
   // se arrivo qui, non ho un ordine martingalato. Conto le perdite 
   total = OrdersHistoryTotal();
   for(int pos=total-20;pos<total;pos++)
   {      
      if(OrderSelect(pos,SELECT_BY_POS,MODE_HISTORY)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_SELL) || (OrderType() == OP_BUY)) && (OrderCloseTime() != 0) ){
         Print("**************  Martin: ordine "+OrderTicket()+" -> "+OrderProfit()+" **************");
         if (OrderProfit() > 0) {newSize = sz;}
         else {newSize = newSize+sz;}
      }
   }
   return newSize;
}


//--------------------------------------------------------+
//             Piazzamento della copertura 
//--------------------------------------------------------+
bool placeProtection(int ot, double prz, double sz){
   int ticket = -1, pt;
   double tp = 0, sl = 0; 
   color c = clrViolet;
   double spread = MarketInfo(nomIndice,MODE_SPREAD);
   if (ot == OP_BUY) {  pt = OP_SELLSTOP;}
   else { pt = OP_BUYSTOP; }
   
   if(ot == OP_BUY) {closeAllSellOrders();}
   if(ot == OP_SELL){closeAllBuyOrders();}
   sz = getProtectionSize();
   
   ticket = OrderSend(nomIndice,pt,sz,prz,2,sl,tp,COMMENT ,SIGNATURE,0,c);
   
   return true;
   
}


//--------------------------------------------------------+
//      Trasformo gli ordini aperti in copertura
//--------------------------------------------------------+
bool convertOrderToProtection(int ot){
   int total = OrdersTotal();
   int ticket = -1;
   double tp = 0, sl = 0, prz = 0, pt, sz=0;
   color c = clrViolet;
   double spread = MarketInfo(nomIndice,MODE_SPREAD);
   if (ot == OP_BUY) {  pt = OP_BUYSTOP;}
   else { pt = OP_SELLSTOP; }
   
   if (ot == OP_BUY) {prz = High[iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,4,1)]+2*spread*Point; }
   if (ot == OP_SELL){prz = Low[iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,4,1)]-spread*Point; }

   for(int pos=0;pos<total;pos++)
   {
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == ot) && (OrderCloseTime() == 0) ) sz += OrderLots();
   }
      
   sz = NormalizeDouble(sz,2);
   
   ticket = OrderSend(nomIndice,pt,sz,prz,2,sl,tp,COMMENT ,SIGNATURE,0,c);

   return true;
   
}

//--------------------------------------------------------+
//           Chiude tutti gli ordini sell aperti 
//--------------------------------------------------------+
bool closeAllSellOrders(){
   int total = OrdersTotal();
   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0) ){
         closeOrder(OrderTicket());
         pos--;
      }
   }
   
   return result;       
   
}


//--------------------------------------------------------+
//           Chiude tutti gli ordini buy aperti 
//--------------------------------------------------------+
bool closeAllBuyOrders(){
   int total = OrdersTotal();
   bool result = true;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY) && (OrderCloseTime() == 0) ) {
         Print("******* closeAllBuyOrders: tkt "+OrderTicket());
         closeOrder(OrderTicket());
         pos--;
         
      }
   }
   
   return result;       
   
}


//--------------------------------------------------------+
//           Chiusura totale di un ordine 
//--------------------------------------------------------+
bool closeOrder(int tkt){
   double price = MarketInfo(nomIndice,MODE_BID);
   color c = clrViolet;
   if (!OrderSelect(tkt,SELECT_BY_TICKET,MODE_TRADES)) return false;
   
   if(OrderType() == OP_SELL) price = MarketInfo(nomIndice,MODE_ASK);
   
   if(!OrderClose(tkt,OrderLots(),price,2,c)) {Print("Errore nella chiusura di un ordine: "+(string)GetLastError()); return false;};
   
   return true;
}

//--------------------------------------------------------+
//           Determina dimensione della copertura 
//--------------------------------------------------------+
double getProtectionSize(){
   int total = OrdersTotal();
   double result = 0;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_BUY) || (OrderType() == OP_SELL) ) && (OrderCloseTime() == 0) ) result += OrderLots();
   }
   
   return result;       

}


//--------------------------------------------------------+
//           Sposta tutti i TP al posto di quello nuovo 
//--------------------------------------------------------+
double moveTakeProfit(int ot, double tp){
   int total = OrdersTotal();
   double result = 0;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == ot) && (OrderCloseTime() == 0) && (OrderTakeProfit() != tp)) {
         OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),tp,0,clrBeige);
      }
   }
   
   return result;       

}



//--------------------------------------------------------+
//                Chiusura in base al SAR 
//--------------------------------------------------------+
/*
bool stoppedByTMA(int ot){
   double actualTMA = 0;
   if(ot==OP_BUY)  {actualTMA = iCustom(nomIndice,0,"Downloads\\TMA_Channel_End_Point",TMA_Period,0,100,3,0,1);}
   if(ot==OP_SELL) {actualTMA = iCustom(nomIndice,0,"Downloads\\TMA_Channel_End_Point",TMA_Period,0,100,3,2,1);}
   double actualPrice = MarketInfo(nomIndice,MODE_BID);
   bool result = false;
   
   if ( (ot == OP_BUY)  && (actualPrice > actualTMA) ) result = true;
   if ( (ot == OP_SELL) && (actualPrice < actualTMA) ) result = true;
   
   return result;
}
*/

//-----------------------------------------------------------------+
// Verifica: alle 20:50 (orario server, 21 in italia) chiudo tutto
//-----------------------------------------------------------------+
bool timeToCloseAll(){
   if (TimeHour(TimeCurrent()) >= endingHour) {
      closeAllBuyOrders();
      closeAllSellOrders();
      closeSparePendingOrders();
   }
   return true;
}

//-----------------------------------------------------------------+
// Verifica se � venerd� sera: alle 21:30 chiudo tutto
//-----------------------------------------------------------------+
bool isFridayNight(){
   if( (DayOfWeek() == 5) && (TimeHour(TimeCurrent()) == 20) ) return true;
   else return false;
}

//-----------------------------------------------------------------+
// Verifica raggiungimento profitto minimo per chiusura parziale 
//-----------------------------------------------------------------+
bool minGainReached(int tkt){  
   if (!OrderSelect(tkt,SELECT_BY_TICKET,MODE_TRADES)) return false;
   if(OrderLots()< POWER) return false; // se l'ordine � gi� stato ridotto, non lo riduco ulteriormente
   double price = MarketInfo(nomIndice,MODE_BID);
   double actualGain = price - OrderOpenPrice();
   if (OrderType()==OP_SELL) actualGain = (actualGain*-1); 
   double originalRisk = MathAbs(OrderOpenPrice()-OrderStopLoss());
   
   if (actualGain > originalRisk) return true;
   else return false;

}

bool partialClose(int tkt){
   if (!partialCloseEnabled) return false;
   
   double price = MarketInfo(nomIndice,MODE_BID);
   color c = clrYellow;
   if (!OrderSelect(tkt,SELECT_BY_TICKET,MODE_TRADES)) return false;  
   if(OrderType() == OP_SELL) price = MarketInfo(nomIndice,MODE_ASK);
   double minLot = MarketInfo(nomIndice,MODE_MINLOT);
   int digits = 0;

   if(minLot == 0.1)    digits=1;
   if(minLot == 0.01)   digits=2;
   if(minLot == 0.001)  digits=3;

   double halfLots = NormalizeDouble( (OrderLots()/2), digits);
   
   //if(!OrderModify(tkt,OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),OrderExpiration())) {Print("Errore nella modifica dello SL ordine: "+(string)GetLastError()); return false;}
   // INFO : La chiusura a pareggio peggiora leggermente le performance. Non di molto, ma le peggiora.
   if(!OrderClose(tkt,halfLots,price,2,c)) {Print("Errore nella chiusura PARZIALE di un ordine: "+(string)GetLastError()); return false;}
   
   return true;
}

//------------------------------------------------------------+
//--------------- SIZE AUTOMATICA ----------------------------+
//------------------------------------------------------------+ 
double getSize(int risk, double distance)
{

   //if (usePercentageRisk == false) return POWER;
   
   double equity = AccountEquity();
   double amountRisked = equity/100*risk;
   double finalSize = 0;
   double tickValue = MarketInfo(nomIndice,MODE_TICKVALUE); //valore di un tick con un lotto 
   double minLot = MarketInfo(nomIndice,MODE_MINLOT);
   
   distance = distance/Point; //la distanza deve sempre essere un intero
      
   finalSize = amountRisked/(tickValue*distance);
   
   // arrotondo i lotti in base a quello che pu� accettare questo strumento
   if (minLot == 1) finalSize = NormalizeDouble(finalSize,0);
   if (minLot == 0.1) finalSize = NormalizeDouble(finalSize,1);
   if (minLot == 0.01) finalSize = NormalizeDouble(finalSize,2);
   
   
   //Print("getSize() - Risk="+(string)risk+" - Distance="+(string)distance+" - amountRisked="+(string)amountRisked+" - finalSize="+(string)finalSize);
   if (finalSize < minLot) finalSize = minLot;
   return finalSize;

}

// ==================================
//            Screen Log 
// ==================================
int screenLog()

   {


   

    Comment( "\n ","\n ","\n ","\n ",
            "\n ",bot_name, ": ",nomIndice,

            "\n ",
            
            "\n Base POWER: ",POWER,

            "\n ",
  
            "\n +-----------------------------   ",
            "\n BUY Conditions   : 0.",buyConditions[0]," 1.",buyConditions[1]," 2.",buyConditions[2]," 3.",buyConditions[3]," 4.",buyConditions[4],
            "\n SELL Conditions  : 0.",sellConditions[0]," 1.",sellConditions[1]," 2.",sellConditions[2]," 3.",sellConditions[3]," 4.",sellConditions[4],
            "\n +-----------------------------   ",
            "\n Time: ",TimeCurrent(),


            "");

   return(0);

   }