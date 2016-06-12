//+------------------------------------------------------------------+
//|                                                   IncredocqB.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, Y3"
#property link      "https://www.y3web.it"
#property version   "2.00"
#property strict
// ============== NOTE ========================
// la versione 2.0 utilizza l'ingresso di Maxx in trend


string bot_name = "TrendFollower";
string nomIndice = "GER30"; //sovrascritto dopo in init()

extern int SIGNATURE = 0039001;
extern string COMMENT = "Y3TF";
extern double POWER = 20;
//extern int slowMA_period = 20;
//extern int fastMA_period = 20;
//extern int TP_multiplier = 4;
extern int MinMax_distance = 6;
extern double sarStep = 0.01;
extern bool partialCloseEnabled = true;
extern bool usePercentageRisk = 0;


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
   
   if(   (isUpTrend()) 
      && (isUpSignal()) 
      && (!existOrder(OP_BUY))
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_BUY))
     )   
         openOrder(OP_BUY, POWER);
   
   

   // ------ Close Buy Orders, if needed ------
   for(int pos=0;pos<OrdersTotal();pos++)
   {
      if( (OrderSelect(pos,SELECT_BY_POS)==false)
      || (OrderSymbol() != nomIndice)
      || (OrderMagicNumber() != SIGNATURE)
      || (OrderType() != OP_BUY)) continue;
      
      //clausole di chiusura
      if (   (stoppedBySAR(OP_BUY))                                     // se il SAR si gira, chiudo
          //|| (brokeLastBar(OP_BUY))                                     // se viola il minimo ella barra precedente
          || (minGainReached(OrderTicket()))                             // se il profitto raggiunge l'1:1 chiudo
         )                      
        closeOrder(OrderTicket());

      // --- chiusura parziale ---
      if (minGainReached(OrderTicket())
      && (OrderStopLoss()<OrderOpenPrice()) ) //se ho messo lo stop in pari non dimezzo più la posizione
         partialClose(OrderTicket());
   }

      
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
   
   if(   (isDownTrend()) 
      && (isDownSignal()) 
      && (!existOrder(OP_SELL))
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_SELL))
     )   
         openOrder(OP_SELL, POWER);

   
   // ------ Close Sell Orders, if neede ------
   for(int pos=0;pos<OrdersTotal();pos++)
   {
      if( (OrderSelect(pos,SELECT_BY_POS)==false)
      || (OrderSymbol() != nomIndice)
      || (OrderMagicNumber() != SIGNATURE)
      || (OrderType() != OP_SELL)) continue;
      
      // --- clausole di chiusura ---
      if (   (stoppedBySAR(OP_SELL))                                    // se il SAR si gira, chiudo
          //|| (brokeLastBar(OP_SELL))                                    // se viola il massimo ella barra precedente
          || (minGainReached(OrderTicket()))                             // se il profitto raggiunge l'1:1 chiudo
         )
         closeOrder(OrderTicket());

      // --- chiusura parziale ---
      if (minGainReached(OrderTicket())
      && (OrderStopLoss()>OrderOpenPrice())) //se ho messo lo stop in pari non dimezzo più la posizione
         partialClose(OrderTicket());
   }
   


   
   // screen Log
   //screenLog();
   
}
//+------------------------------------------------------------------+
//+----------------      OnTick End     -----------------------------+
//+------------------------------------------------------------------+


//-------------------------------------------------+
//    Sono in un trend UP 
//-------------------------------------------------+
bool isUpTrend(){

   double actualSAR = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,0);
   double oldSar_1 = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,1);
   double oldSar_2 = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,2);
   double oldSar_3 = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,3);
   double actualPrice = MarketInfo(nomIndice, MODE_BID);

   
   if( (actualPrice > actualSAR) && (Close[1] > oldSar_1) && (Close[2] > oldSar_2) && (Close[3] > oldSar_3) ) 
       return true;
   else return false;
   
}



//-------------------------------------------------+
//    Sono in un trend DOWN 
//-------------------------------------------------+
bool isDownTrend(){

   double actualSAR = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,0);
   double oldSar_1 = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,1);
   double oldSar_2 = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,2);
   double oldSar_3 = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,3);
   double actualPrice = MarketInfo(nomIndice, MODE_BID);

   
   if( (actualPrice < actualSAR) && (Close[1] < oldSar_1) && (Close[2] < oldSar_2) && (Close[3] < oldSar_3) ) 
      return true;
   else return false;   
}


//----------------------------------------------------------------+
//    Si verifica una barra di colore opposto e la si sfonda UP
//----------------------------------------------------------------+
bool isUpSignal(){
   double atr = iATR(nomIndice,PERIOD_CURRENT,14,1);
   string lastBarDirection = "up";
   string prevBarDirection = "up";
   double lastBarSize = MathAbs(High[1]-Low[1]);
   //double prevBarSize = MathAbs(High[2]-Low[2]);
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   bool result = false;
   
   if( Open[1]>Close[1] ) lastBarDirection = "down";
   if( Open[2]>Close[2] ) prevBarDirection = "down";

   
   if(   (lastBarDirection == "up") 
         && (prevBarDirection == "down") 
         && (actualPrice > High[1]) 
         //&& (lastBarSize >= atr)
     ) result = true;
   // TODO: aggiungere qui sopra anche le condizioni sulla dimensione delle barre (vola)
   
   return result;
   
}


//----------------------------------------------------------------+
//    Si verifica una barra di colore opposto e la si sfonda DOWN
//----------------------------------------------------------------+
bool isDownSignal(){
   double atr = iATR(nomIndice,PERIOD_CURRENT,14,1);
   string lastBarDirection = "up";
   string prevBarDirection = "up";
   double lastBarSize = MathAbs(High[1]-Low[1]);
   //double prevBarSize = MathAbs(High[2]-Low[2]);
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   bool result = false;
   
   if( Open[1]>Close[1] ) lastBarDirection = "down";
   if( Open[2]>Close[2] ) prevBarDirection = "down";

   
   if(   (lastBarDirection == "down") 
         && (prevBarDirection == "up") 
         && (actualPrice < Low[1]) 
         //&& (lastBarSize >= atr)
     ) result = true;
   // TODO: aggiungere qui sopra anche le condizioni sulla dimensione delle barre (vola)
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

bool brokeLastBar(int ot){
   double lastLow = Low[1];
   double lastHigh = High[1];
   double actualPrice = MarketInfo(nomIndice, MODE_BID);
   bool result = false;

   if((ot == OP_BUY) && (actualPrice < lastLow)) {result = true;}
   if((ot == OP_SELL) && (actualPrice > lastHigh)) {result = true;}

   return result;
}

//-------------------------------------------------+
//    Ho rotto il max precedente 
//-------------------------------------------------+
bool maxIsBroken(){
   int shift = iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,3,1); // il max precedente è quello della barra col minimo locale
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
   int shift = iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,3,1); // il min precedente è quello della barra col massimo locale
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
//       Eiste già un ordine aperto in questa direzione 
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
   if (ot == OP_BUY) {prz = MarketInfo(nomIndice,MODE_ASK); tp = prz+((prz-Low[1])*10); sl = Low[iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,3,1)]-2*Point;   c = clrBlue;}
   if (ot == OP_SELL){prz = MarketInfo(nomIndice,MODE_BID); tp = prz-((High[1]-prz)*10); sl = High[iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,3,1)]+2*Point; c = clrRed; }

   tp = 0;
   sz = getSize(POWER,MathAbs(prz-sl)/Point);
   //sz = Martin(sz);

   ticket = OrderSend(nomIndice,ot,sz,prz,2,sl,tp,COMMENT ,SIGNATURE,0,c);


   return true;
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
//                Chiusura in base al SAR 
//--------------------------------------------------------+
bool stoppedBySAR(int ot){
   double actualSAR = iSAR(nomIndice,PERIOD_CURRENT,sarStep,0.2,0);
   double actualPrice = MarketInfo(nomIndice,MODE_BID);
   bool result = false;
   
   if ( (ot == OP_BUY)  && (actualPrice < actualSAR) ) result = true;
   if ( (ot == OP_SELL) && (actualPrice > actualSAR) ) result = true;
   
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
   //if(OrderLots()< POWER) return false; // se l'ordine è già stato ridotto, non lo riduco ulteriormente
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
   
   Print("******************** chiusura parziale ordine "+tkt+" , da "+OrderLots()+" a "+halfLots+" lotti ********************");
   
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
   // vers. 2.0 funzionante
   if (usePercentageRisk == false) return POWER;
   
   double equity = AccountEquity();
   double amountRisked = equity/100*risk;
   double finalSize = 0;
   double tickValue = MarketInfo(nomIndice,MODE_TICKVALUE); //valore di un tick con un lotto 
   double minLot = MarketInfo(nomIndice,MODE_MINLOT);
   double maxLots = MarketInfo(nomIndice,MODE_MAXLOT);
   //Print("/////////////////// distance="+distance+"   ///////////////////");
      
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


//--------------------------------------------------------+
//             Martingalone 
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
                  if(i>0) {newSize = newSize*2;} //vero martingale. utilizzare valore di i per fare iniziare le moltiplicazioni solo da un certo numero di sconfitte in poi
              }
      }
   }

   if (newSize > maxLots) newSize = maxLots;
   
   return newSize;
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