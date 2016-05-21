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
string nomIndice = "GER30"; //sovrascritto dopo in init()

extern int SIGNATURE = 0077330;
extern string COMMENT = "Y3_Yoyo";
extern double POWER = 20;
extern bool partialCloseEnabled = true;
extern int atrPeriod = 14;
extern double atrMultiplier = 3.0;
extern int startingHour = 8;
extern int endingHour = 23;
extern double minAMADegree = 0.0;
extern int protectionStartDistance = 100;
extern int protectionCloseDistance = 0;
int MinMax_distance = 10;
double atr = 0;
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
   atr = NormalizeDouble(iATR(nomIndice,PERIOD_CURRENT,atrPeriod,1),Digits);
   
   // alle 21:00 chiudo comunque tutto, aperti e pendenti
   //timeToCloseAll();


     

   // ===============
   // Buy conditions
   // ===============

   
   if(   (isUpFromAMA())
      && (TimeHour(TimeCurrent()) >= startingHour)
      && (TimeHour(TimeCurrent()) < endingHour)
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_BUY))
      && (!existOrder(OP_BUY))
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
          (stoppedByAMA(OP_BUY))
      ) closeOrder(OrderTicket());
      
      
      // --- chiusura parziale ---
      //if (minGainReached(OrderTicket()))
      //   partialClose(OrderTicket());
   }



      
   // ===============
   // Sell conditions
   // ===============

   
   if(   (isDownFromAMA())
      && (TimeHour(TimeCurrent()) >= startingHour)
      && (TimeHour(TimeCurrent()) < endingHour)      
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_SELL))
      && (!existOrder(OP_SELL))
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
          (stoppedByAMA(OP_SELL))

      ) closeOrder(OrderTicket());
      
      
      // --- chiusura parziale ---
      //if (minGainReached(OrderTicket()))
      //   partialClose(OrderTicket());
   }
   
   

   
   // screen Log
   //screenLog();
   
}
//+------------------------------------------------------------------+
//+----------------      OnTick End     -----------------------------+
//+------------------------------------------------------------------+







//-------------------------------------------------+
//    il prezzo si è allontanato UP
//-------------------------------------------------+
bool isUpFromAMA(){
   
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   double AMAzero  = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,0),Digits);
   double distanceFromAMA = NormalizeDouble(actualPrice-AMAzero,Digits);
   double requiredDistance = NormalizeDouble(atr*atrMultiplier,Digits);
   bool result = false;
   if (distanceFromAMA >= requiredDistance) {result = true;}    //Print("***********   isUpFromAMA   atr:"+atr+"   -  distanceFromAMA:"+distanceFromAMA+"   - requiredDistance:"+requiredDistance+"   **********");}
   
   return result;
   
}


//-------------------------------------------------+
//    il prezzo si è allontanato UP
//-------------------------------------------------+
bool isDownFromAMA(){
   
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   double AMAzero  = NormalizeDouble(iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,0),Digits);
   double distanceFromAMA = NormalizeDouble(AMAzero-actualPrice,Digits);
   double requiredDistance = NormalizeDouble(atr*atrMultiplier,Digits);
   bool result = false;
   if (distanceFromAMA >= requiredDistance) {result = true;}//    Print("***********   isDownFromAMA   atr:"+atr+"   -  distanceFromAMA:"+distanceFromAMA+"   - requiredDistance:"+requiredDistance+"   **********");}

   
   return result;
   
}



//-------------------------------------------------+
//    Il prezzo tocca l'ama
//-------------------------------------------------+
bool stoppedByAMA(int ot){

   double actualPrice = MarketInfo(nomIndice, MODE_BID);   
   double AMAzero = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1);
   
   
   bool result = false;
   
 
   if((ot==OP_BUY) && (actualPrice < AMAzero)) result = true;
   if((ot==OP_SELL) && (actualPrice > AMAzero)) result = true;

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
   double AMAzero = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1);
   if (ot == OP_BUY) {  prz = MarketInfo(nomIndice,MODE_ASK);
                        sl  = NormalizeDouble(AMAzero,Digits); 
                     }
   if (ot == OP_SELL){  prz = MarketInfo(nomIndice,MODE_BID); 
                        sl  = NormalizeDouble(AMAzero,Digits);
                     }

   sz = getSize(2,MathAbs(prz-sl)/Point);
   //sl = 0;
   //tp = 0;
   ticket = OrderSend(nomIndice,ot,sz,prz,2,sl,tp,COMMENT ,SIGNATURE,0,c);
   

   return true;
}

//--------------------------------------------------------+
//             Martingalone 
//--------------------------------------------------------+
double Martin(double sz){
   int total = OrdersTotal();
   double newSize = sz;
   bool alreadyOpened = false;
   // c'è già un ordine aperto con size > sz?   
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
   }
   return true;
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
double getSize(int risk, double distance)
{

   //if (usePercentageRisk == false) return POWER;
   
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
     Print("***********  shift:"+shift+"   -    profit:"+profit+"    -    activationDistance:"+activationDistance+"    -    closeDistance:"+closeDistance+"   *************");
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         max_ = High[iHighest(nomIndice,PERIOD_M1,MODE_HIGH,shift,0)]; Print("isCameBack BUY: profit="+profit+" -- max_="+max_+" -- shift="+shift);
         if ( (max_ - OrderOpenPrice() >= activationDistance) && (MarketInfo(nomIndice,MODE_BID) <= (OrderOpenPrice()+closeDistance) ) )
         {result = true; Print("Protector: Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         min_ = Low[iLowest(nomIndice,PERIOD_M1,MODE_LOW,shift,0)]; Print("isCameBack SELL: profit="+profit+" -- min_="+min_+" -- shift="+shift);
         if ((OrderOpenPrice() - min_ >= activationDistance) && (MarketInfo(nomIndice,MODE_BID) >= (OrderOpenPrice()-closeDistance) ) )
         {result = true; Print("Protector: Sell ", tkt, " is Coming Back: CHIUDO");}
      }
       
   }
   
   return result;

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