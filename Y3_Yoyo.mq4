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
// GER30 M5 Default value
// EURUSD - ToDo


string bot_name = "Y3_Yoyo";
string nomIndice = "EURUSD"; //sovrascritto dopo in init()

extern int SIGNATURE = 777333;
extern string COMMENT = "Y3_Yoyo";
extern double POWER = 0.1;
extern bool partialCloseEnabled = true;
int atrPeriod = 14;
double atrMultiplier = 6.0;
bool usePercentageRisk = false;
int maPeriod = 100;
extern int distancePeriod = 14;
extern int martinMultiplier = 2;
int protectionStartDistance = 100;
int protectionCloseDistance = 0;
extern string openHours = "8,9,10,11,12,13,14,15,16,17";                            

double atr = 0;
double entryDistance = 0;
datetime lastAnalizedBarTime;       // per eseguire alcuni controlli una sola volta per barra: inizializzato in init
bool enabledHours[24];              // array con le singole ore in cui c'è indicato se tradare o no (true o false)



//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   nomIndice = Symbol();
   setHours(); //imposto le ore in cui è consentito fare trading
   createDebugLabel(); // inizializzo la finestra di debug
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
   atr = NormalizeDouble(iATR(nomIndice,PERIOD_CURRENT,atrPeriod,1),Digits);
   if (iBarShift(nomIndice,0,lastAnalizedBarTime,false) > 0 ) //(Volume[0] == 1)
   {
      entryDistance = getDistance(distancePeriod);
      //aggiorno lastAnalizedBarTime in modo che fino alla prossima barra tutto questo non venga eseguito
      lastAnalizedBarTime = Time[0];
      
   }

   // ===============
   // Buy conditions
   // ===============

   
   if(   (isDownFromMA())
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_BUY)) 
      //&& (!isFirstBreakout(OP_BUY)) 
      //&& (!existOrder(OP_BUY))
      //&& ((medianTargetIsLessThenZero(OP_BUY)) && (!isGoingTooFast(OP_BUY)))  --nel 2016 perde e basta. non ho provato altri anni.
      && (medianTargetIsLessThenZero(OP_BUY))
      && (enabledHours[Hour()])
     )   {
        openOrder(OP_BUY, POWER);
     }

   for(int pos=0;pos<OrdersTotal();pos++)
   {
      if( (OrderSelect(pos,SELECT_BY_POS)==false)
      || (OrderSymbol() != nomIndice)
      || (OrderMagicNumber() != SIGNATURE)
      || (OrderType() != OP_BUY)) continue;

      
      // chiusura SINGOLO ordine 
      if ( //(protector(OrderTicket(), protectionStartDistance, protectionCloseDistance))            // se ha raggiunto una certa percentuale di profitto e poi torna indietro
             (stoppedByMA(OP_BUY))
             //|| (stoppedByBand(OP_BUY))
          //|| (brokeOpenBar(OP_BUY, iBarShift(nomIndice,PERIOD_CURRENT,OrderOpenTime(),false)))
      ) closeOrder(OrderTicket());
      
      
      // --- chiusura parziale ---
      //if (minGainReached(OrderTicket()))
      //   partialClose(OrderTicket());
   }



      
   // ===============
   // Sell conditions
   // ===============

   
   if(   (isUpFromMA())
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_SELL))
      //&& (!isFirstBreakout(OP_SELL)) 
      //&& (!existOrder(OP_SELL))
      //&& (medianTargetIsLessThenZero(OP_SELL) && (!isGoingTooFast(OP_SELL)))  //nel 2016 perde e basta. Non ho provato altri anni.
      && (medianTargetIsLessThenZero(OP_SELL))
      && (enabledHours[Hour()])
     )   {
         openOrder(OP_SELL, POWER);
     }

   for(int pos=0;pos<OrdersTotal();pos++)
   {
      if( (OrderSelect(pos,SELECT_BY_POS)==false)
      || (OrderSymbol() != nomIndice)
      || (OrderMagicNumber() != SIGNATURE)
      || (OrderType() != OP_SELL)) continue;

      
      // chiusura SINGOLO ordine 
      if (  //(protector(OrderTicket(), protectionStartDistance, protectionCloseDistance))            // se ha raggiunto una certa percentuale di profitto e poi torna indietro
             (stoppedByMA(OP_SELL))
             //|| (stoppedByBand(OP_SELL))
         //|| (brokeOpenBar(OP_SELL, iBarShift(nomIndice,PERIOD_CURRENT,OrderOpenTime(),false)))
      ) closeOrder(OrderTicket());
      
      
      // --- chiusura parziale ---
      //if (minGainReached(OrderTicket()))
      //   partialClose(OrderTicket());
   }
   
   

   
   // screen Log
   screenLog();
   
}
//+------------------------------------------------------------------+
//+----------------      OnTick End     -----------------------------+
//+------------------------------------------------------------------+







//-------------------------------------------------+
//    il prezzo si è allontanato UP
//-------------------------------------------------+
bool isUpFromMA(){
   
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   double MAzero  = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,0),Digits);
   double distanceFromMA = NormalizeDouble(actualPrice-MAzero,Digits);
   double requiredDistance = entryDistance;// NormalizeDouble(atr*atrMultiplier,Digits);
   bool result = false;
   if (distanceFromMA >= requiredDistance) {result = true;}    //Print("***********   isUpFromAMA   atr:"+atr+"   -  distanceFromAMA:"+distanceFromAMA+"   - requiredDistance:"+requiredDistance+"   **********");}
   
   return result;
   
}


//-------------------------------------------------+
//    il prezzo si è allontanato UP
//-------------------------------------------------+
bool isDownFromMA(){
   
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   double MAzero  = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,0),Digits);
   double distanceFromMA = NormalizeDouble(MAzero-actualPrice,Digits);
   double requiredDistance = entryDistance;//NormalizeDouble(atr*atrMultiplier,Digits);
   bool result = false;
   if (distanceFromMA >= requiredDistance) {result = true;}//    Print("***********   isDownFromAMA   atr:"+atr+"   -  distanceFromAMA:"+distanceFromAMA+"   - requiredDistance:"+requiredDistance+"   **********");}

   
   return result;
   
}


//-------------------------------------------------+
//    la media raggiunge il prezzo di apertura
//-------------------------------------------------+
bool medianTargetIsLessThenZero(int ot){
   bool result = false;  
   int total = OrdersTotal();
   double lots = 0;
   double opens = 0;
   double medianOpen = 0;
   double lastBestPrice = 0;
   double MAzero  = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,0),Digits);
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   for(int pos=0;pos<total;pos++)
   {
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY) && (OrderCloseTime() == 0) && (ot == OP_BUY) )
         {
            if(lots==0) { lastBestPrice=OrderOpenPrice(); }
            else        { if(OrderOpenPrice()<lastBestPrice) lastBestPrice=OrderOpenPrice(); }
            lots+=OrderLots(); opens+=OrderOpenPrice()*OrderLots();
         }
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0) && (ot == OP_SELL) )
         {
            if(lots==0) { lastBestPrice=OrderOpenPrice(); }
            else        { if(OrderOpenPrice()>lastBestPrice) lastBestPrice=OrderOpenPrice(); }
            lots+=OrderLots(); opens+=OrderOpenPrice()*OrderLots();
         }   }
   
   if(lots>0) {
      //medianOpen = NormalizeDouble(opens/lots,Digits);
      if( (ot==OP_BUY) && (lastBestPrice > MAzero)  && (actualPrice < lastBestPrice) ) result = true;
      if( (ot==OP_SELL) && (lastBestPrice < MAzero) && (actualPrice > lastBestPrice) ) result = true;
   }
   else {result = true;} // non avendo ordini attivi, posso aprirne di nuovi
   
   return result;    
   
}

// =============================================================
//      Non prendo il primo segnale, ma uno dei successivi
// =============================================================
bool isFirstBreakout(int ot){  
   if(ObjectFind(0,"BuyPoint"+(string)Time[3]) < 0) return true; //se sono appena partito, non ho storico di segnali
   bool result = true;
   bool wasSignal = false;
   if(ot==OP_BUY){
      if(Low[1] <  ObjectGetDouble(0,"BuyPoint"+(string)Time[1],OBJPROP_PRICE) ) {wasSignal = true;}
      if(Low[2] <  ObjectGetDouble(0,"BuyPoint"+(string)Time[2],OBJPROP_PRICE) ) {wasSignal = true;}
      if(Low[3] <  ObjectGetDouble(0,"BuyPoint"+(string)Time[3],OBJPROP_PRICE) ) {wasSignal = true;}
   }
   if(ot==OP_SELL){
      if(High[1] >  ObjectGetDouble(0,"SellPoint"+(string)Time[1],OBJPROP_PRICE) ) {wasSignal = true;}
      if(High[2] >  ObjectGetDouble(0,"SellPoint"+(string)Time[2],OBJPROP_PRICE) ) {wasSignal = true;}
      if(High[3] >  ObjectGetDouble(0,"SellPoint"+(string)Time[3],OBJPROP_PRICE) ) {wasSignal = true;}
   }
   
   if(wasSignal) result = false;
   
   return result;
   
}


//-------------------------------------------------+
//    Il prezzo sta scappando velocemente (test)
//-------------------------------------------------+
bool isGoingTooFast(int ot){
   // considero il prezzo veloce se anche la barra precedente attraversava la banda
   bool result = false;
   double lastPrice = 0;
   double band  = 0;
   
   if(ot==OP_BUY) {
      band = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1),Digits) - entryDistance; //lower band
      lastPrice = Low[1];
      if(lastPrice < band) result = true;
   }
   else{
      band = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1),Digits) + entryDistance; //upper band
      lastPrice = High[1];
      if(lastPrice > band) result = true;   
   }
   
   return result;
}



//-------------------------------------------------+
//    Il prezzo tocca l'ma
//-------------------------------------------------+
bool stoppedByMA(int ot){

   double actualPrice = MarketInfo(nomIndice, MODE_BID);   
   double MAzero = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1);
   //double MAzero  = NormalizeDouble(iMA(nomIndice,PERIOD_CURRENT,maPeriod,0,MODE_SMMA,PRICE_TYPICAL,0),Digits);
   
   
   bool result = false;
   
 
   if((ot==OP_BUY) && (actualPrice > MAzero)) result = true;
   if((ot==OP_SELL) && (actualPrice < MAzero)) result = true;

   return result;
   
}



//-------------------------------------------------+
//    Il prezzo tocca la banda opposta
//-------------------------------------------------+
bool stoppedByBand(int ot){

   double actualPrice = MarketInfo(nomIndice, MODE_BID);   
   double band = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1) + entryDistance;  //upper band
   if (ot == OP_SELL) band = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1) - entryDistance;     //lower band
   bool result = false;
   
 
   if((ot==OP_BUY) && (actualPrice > band)) result = true;
   if((ot==OP_SELL) && (actualPrice < band)) result = true;

   return result;
   
}


//-------------------------------------------------+
//    Ho rotto il max precedente 
//-------------------------------------------------+

bool brokeOpenBar(int ot, int shift){
   double openLow = Low[shift];
   double openHigh = High[shift];
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   bool result = false;

   if((ot == OP_BUY) && (actualPrice < openLow)) {result = true;}
   if((ot == OP_SELL) && (actualPrice > openHigh)) {result = true;}

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
//    Ho già un ordine aperto in questa barra? 
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
//    Ho già n ordini aperti e chiusi in questa barra? 
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
//       Eiste già un ordine aperto  in questa direzione
//-----------------------------------------------------------------+
bool existOrder(int ot) 
{
   int total = OrdersTotal();
   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY) && (OrderCloseTime() == 0) && (ot == OP_BUY) )         
         result = true;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0) && (ot == OP_SELL) )         
         result = true;
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
                        
                     }
   if (ot == OP_SELL){  prz = MarketInfo(nomIndice,MODE_BID); 
                       
                     }

   sz = getSize(POWER,MathAbs(prz-sl)/Point);
   sz = martinOnOpen(sz);
   ticket = OrderSend(nomIndice,ot,sz,prz,2,sl,tp,COMMENT ,SIGNATURE,0,c);
   

   return true;
}

//--------------------------------------------------------+
//             Martingalone sullo storico
//--------------------------------------------------------+
double Martin(double sz){
   int total = OrdersTotal();
   double newSize = sz;
   bool alreadyOpened = false;
   double maxLots = MarketInfo(nomIndice,MODE_MAXLOT);
      
   // c'è già un ordine aperto con size > sz?   
   for(int pos=0;pos<total;pos++)
   {      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_SELL) || (OrderType() == OP_BUY)) && (OrderCloseTime() == 0) ){
         if (OrderLots() >= sz) return sz;
      }
   }
   
   // se arrivo qui, non ho un ordine martingalato. Conto le perdite 
   total = OrdersHistoryTotal();
   int i = 0;
   for(int pos=total-20;pos<total;pos++)
   {  
        
      if(OrderSelect(pos,SELECT_BY_POS,MODE_HISTORY)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_SELL) || (OrderType() == OP_BUY)) && (OrderCloseTime() != 0) ){
         //Print("**************  Martin: ordine "+OrderTicket()+" -> "+OrderProfit()+" **************");
         if (OrderProfit() > 0) {i=0; newSize = sz;}
         else {   i++; 
                  //newSize = newSize+sz; //falso martingale: somma sz ogni volta invece di moltiplicare
                  if(i>0) {newSize = newSize*martinMultiplier;} //vero martingale. utilizzare valore di i per fare iniziare le moltiplicazioni solo da un certo numero di sconfitte in poi
              }
      }
   }

   if (newSize > maxLots) newSize = maxLots;
   
   return newSize;
}




//--------------------------------------------------------+
//             Martingalone sugli ordini aperti
//--------------------------------------------------------+
double martinOnOpen(double sz){
   int total = OrdersTotal();
   double newSize = sz;
   bool alreadyOpened = false;
   double maxLots = MarketInfo(nomIndice,MODE_MAXLOT);
      
   // c'è già un ordine aperto con size > sz?   
   for(int pos=0;pos<total;pos++)
   {      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == OP_SELL) || (OrderType() == OP_BUY)) && (OrderCloseTime() == 0) ){
         {newSize = newSize*martinMultiplier;}
      }
   }
   

   if (newSize > maxLots) newSize = maxLots;
   
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
   
   if(!OrderClose(tkt,OrderLots(),price,0,c)) {Print("Errore nella chiusura di un ordine: "+(string)GetLastError()); return false;};
   
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
         bool r = OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss(),tp,0,clrBeige);
      }
   }
   
   return result;       

}






//-----------------------------------------------------------------+
// Verifica se è venerdì sera: alle 21:30 chiudo tutto
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
   if(MathAbs(OrderOpenPrice()-OrderStopLoss()) < 10*Point) return false; // se l'ordine è già stato ridotto, non lo riduco ulteriormente
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
   
   if(!OrderModify(tkt,OrderOpenPrice(),OrderOpenPrice(),OrderTakeProfit(),OrderExpiration())) {Print("Errore nella modifica dello SL ordine: "+(string)GetLastError()); return false;}
   // INFO : La chiusura a pareggio peggiora leggermente le performance. Non di molto, ma le peggiora.
   if(!OrderClose(tkt,halfLots,price,2,c)) {Print("Errore nella chiusura PARZIALE di un ordine: "+(string)GetLastError()); return false;}
   
   return true;
}

//------------------------------------------------------------+
//--------------- SIZE AUTOMATICA ----------------------------+
//------------------------------------------------------------+ 
double getSize(double risk, double distance)
{

   if (usePercentageRisk == false) return POWER;
   
   double equity = AccountEquity();
   double amountRisked = equity/100*risk;
   double finalSize = 0;
   double tickValue = MarketInfo(nomIndice,MODE_TICKVALUE); //valore di un tick con un lotto 
   double minLot = MarketInfo(nomIndice,MODE_MINLOT);
   double maxLots = MarketInfo(nomIndice,MODE_MAXLOT);
   //Print("/////////////////// distance="+distance+"   ///////////////////");
   //distance = distance/Point; //la distanza deve sempre essere un intero
      
   finalSize = amountRisked/(tickValue*distance);
   //Print("+++++++++++++ distance="+distance+"  -  tickValue="+tickValue+"  +++++++++++++++");
   //Print("***********   finalSize("+finalSize+") = amountRisked("+amountRisked+")/(tickValue*distance)("+tickValue*distance+");      **********");
   
   // arrotondo i lotti in base a quello che può accettare questo strumento
   if (minLot == 1) finalSize = NormalizeDouble(finalSize,0);
   if (minLot == 0.1) finalSize = NormalizeDouble(finalSize,1);
   if (minLot == 0.01) finalSize = NormalizeDouble(finalSize,2);
   
   
   //Print("getSize() - Risk="+(string)risk+" - Distance="+(string)distance+" - amountRisked="+(string)amountRisked+" - finalSize="+(string)finalSize);
   if (finalSize < minLot) finalSize = minLot;
   if (finalSize > maxLots) finalSize = maxLots;
   return finalSize;

}


// ==================================
//            Protector 
// ==================================
bool protector(int tkt,int protectionStart, int protectionClose)
{
   // protectionStart: la percentuale di profitto a cui si attiva il protettore
   // protectionClose: la percentuale che viene protetta, dopo aver raggiunto protectionStart
   
   if (protectionStart >= 100) return false;
   
   int shift;
   double profit, max_, min_ = 0;
   bool result = false;
   double activationDistance = 0;
   double closeDistance = 0;
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      //se questo ordine ha visto sulla carta un profitto pari alla percentuale di profit indicata, se il prezzo ritraccia chiude alla percentuale indicata
      
      shift = iBarShift(nomIndice,PERIOD_M1,OrderOpenTime(),false);
      profit = MathAbs(OrderOpenPrice() - OrderTakeProfit());                    // Guardo la distanza del TP per proteggerne una percentuale
      activationDistance = NormalizeDouble(profit/100*protectionStart, Digits);  // distanza a cui iniziare a proteggere la posizione, in pips
      closeDistance = NormalizeDouble(profit/100*protectionClose, Digits);       // distanza dello stopProfit, in pips
     //Print("***********  shift:"+shift+"   -    profit:"+profit+"    -    activationDistance:"+activationDistance+"    -    closeDistance:"+closeDistance+"   *************");
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         max_ = High[iHighest(nomIndice,PERIOD_M1,MODE_HIGH,shift,0)]; //Print("isCameBack BUY: profit="+profit+" -- max_="+max_+" -- shift="+shift);
         if ( (max_ - OrderOpenPrice() >= activationDistance) && (MarketInfo(nomIndice,MODE_BID) <= (OrderOpenPrice()+closeDistance) ) )
         {result = true; Print("Protector: Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         min_ = Low[iLowest(nomIndice,PERIOD_M1,MODE_LOW,shift,0)]; //Print("isCameBack SELL: profit="+profit+" -- min_="+min_+" -- shift="+shift);
         if ((OrderOpenPrice() - min_ >= activationDistance) && (MarketInfo(nomIndice,MODE_BID) >= (OrderOpenPrice()-closeDistance) ) )
         {result = true; Print("Protector: Sell ", tkt, " is Coming Back: CHIUDO");}
      }
       
   }
   
   return result;

}


// ======================================================
//      Distanza dalla media per entrare contrarian
// ======================================================
double getDistance(int shift){
   if(shift > Bars) shift = Bars;
   double maValue = 0;
   double upDistance = 0;
   double downDistance = 0;
   double tempDistance = 0;
   double maxDistance = 0;
   double result = 0;
   
   for(int i=1; i<shift; i++){
      //maValue = NormalizeDouble(iMA(nomIndice,PERIOD_CURRENT,maPeriod,0,MODE_SMMA,PRICE_TYPICAL,i),Digits);
      maValue = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,i),Digits);
      upDistance = MathAbs(High[i]-maValue);
      downDistance = MathAbs(Low[i]-maValue);
      if (upDistance>downDistance) tempDistance=upDistance;
      else tempDistance=downDistance;
      if (tempDistance > maxDistance) maxDistance = tempDistance;
   }
   
   result = NormalizeDouble((maxDistance/10)*9,Digits);
   //result = NormalizeDouble(result*1.5,Digits);  //test con 2x e 1.5x hanno dato pessimi risultati. Peggiornativissimi!

   // disegno i segni le bande   
   maValue = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1),Digits);
   drawNewEntryPoint(OP_BUY, maValue-result);
   drawNewEntryPoint(OP_SELL, maValue+result);
   
   return result;
   
}



bool setHours(){
   // creo un array temporaneo con le ore indicate dall'utente
   string taResult[];
   ushort sep=StringGetCharacter(",",0);
   StringSplit(openHours,sep,taResult);

   // in ogni ora metto true se ho quell'ora nell'array taResult
   for (int i=0; i<ArraySize(enabledHours); i++){
      enabledHours[i] = false;
      for (int b=0; b<ArraySize(taResult); b++){
         if ((int)taResult[b] == i) enabledHours[i] = true;
      }
   }
   
   return true;
}



// ==================================
//           Debug Label 
// ==================================
bool createDebugLabel(){
   string objName = "debug Label";
   int chart_ID = 0;
   color clr = clrOrange;
   
   if(ObjectFind(0,objName) < 0) 
   {
      ObjectCreate(chart_ID,objName,OBJ_LABEL,0,0,0);
      //--- set label coordinates 
      ObjectSetInteger(chart_ID,objName,OBJPROP_XDISTANCE,100); 
      ObjectSetInteger(chart_ID,objName,OBJPROP_YDISTANCE,20); 
      //--- set the chart's corner, relative to which point coordinates are defined 
      ObjectSetInteger(chart_ID,objName,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      //--- set anchor type 
      ObjectSetInteger(chart_ID,objName,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);       
      //--- set the text 
      ObjectSetString(chart_ID,objName,OBJPROP_TEXT,"This is the debug box");
      //--- set font size 
      ObjectSetInteger(chart_ID,objName,OBJPROP_FONTSIZE,8); 
      //--- set color 
      ObjectSetInteger(chart_ID,objName,OBJPROP_COLOR,clr);       
      
   }
   
   return true;
}


// ==================================
//      Scrive il testo di debug 
// ==================================
bool setDebugText(string txt){
   string objName = "debug Label";
   int chart_ID = 0;
      //--- set the text 
      ObjectSetString(chart_ID,objName,OBJPROP_TEXT,txt);
   return true;

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
            "\n Max Distance   : ",(string)entryDistance,
            //"\n isFirstBreakout(BUY): ",(string)isFirstBreakout(OP_BUY),
            //"\n isFirstBreakout(SELL): ",(string)isFirstBreakout(OP_SELL),
            "\n +-----------------------------   ",
            "\n Time: ",TimeCurrent(),


            "");

   return(0);

   }