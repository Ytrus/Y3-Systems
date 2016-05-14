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


string bot_name = "ReversalAMA";
string nomIndice = "GER30"; //sovrascritto dopo in init()

extern int SIGNATURE = 0039001;
extern string COMMENT = "Y3_REVAMA";
extern double POWER = 20;
extern int TMA_Period = 100;
extern double TMA_K = 3.0;
extern bool partialCloseEnabled = true;
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
   
   if(   (isUnderTMAChannel()) 
      && (isUpAMA()) 
      //&& (!existOrder(OP_BUY))
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
      if (   (stoppedByTMA(OP_BUY))                                       // se il SAR si gira, chiudo
          //|| (isFridayNight())                                          // se è venerdì sera chiudo per evitare il gap del lunedì
          
         )                      
        closeOrder(OrderTicket());

      // --- chiusura parziale ---
      //if (minGainReached(OrderTicket()))
      //   partialClose(OrderTicket());
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
   
   if(   (isOverTMAChannel()) 
      && (isDownAMA()) 
      //&& (!existOrder(OP_SELL))
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
      if (   (stoppedByTMA(OP_SELL))                                      // se il SAR si gira, chiudo
          //|| (isFridayNight())                                          // se è venerdì sera chiudo per evitare il gap del lunedì
         )
         closeOrder(OrderTicket());

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
//    Sono sotto al lower TMA channel 
//-------------------------------------------------+
bool isUnderTMAChannel(){

   double lastAMA = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1);
   double lastLowerChannel = iCustom(nomIndice,0,"Downloads\\TMA_Channel_End_Point",TMA_Period,0,100,TMA_K,2,1);
   bool result = false;
   
   if( (lastAMA < lastLowerChannel) ) 
       result = true;
   return result;
   
}

//-------------------------------------------------+
//    Sono sopra all'upper TMA channel 
//-------------------------------------------------+
bool isOverTMAChannel(){

   double lastAMA = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,0,1);
   double lastUpperChannel = iCustom(nomIndice,0,"Downloads\\TMA_Channel_End_Point",TMA_Period,0,100,TMA_K,0,1);
   bool result = false;
   
   if( (lastAMA > lastUpperChannel) ) 
       result = true;
   return result;
   
}



//-------------------------------------------------+
//    L'AMA segnala il BUY 
//-------------------------------------------------+
bool isUpAMA(){

   double lastAMA = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,1,1);
   double prevAMA = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,1,2);
   bool result = false;
   
   if( (prevAMA == 0) && (lastAMA > 0) ) 
       result = true;
   return result;
   
}


//-------------------------------------------------+
//    L'AMA segnala il SELL 
//-------------------------------------------------+
bool isDownAMA(){

   double lastAMA = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,2,1);
   double prevAMA = iCustom(nomIndice,0,"Downloads\\AMA",9,2,30,2,2,2,2);
   bool result = false;
   
   if( (prevAMA == 0) && (lastAMA > 0) ) 
       result = true;
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
   if (ot == OP_BUY) {prz = MarketInfo(nomIndice,MODE_ASK); sl = Low[iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,10,1)]-200*Point;   c = clrBlue;}
   if (ot == OP_SELL){prz = MarketInfo(nomIndice,MODE_BID); sl = High[iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,10,1)]+200*Point; c = clrRed; }

   //sz = getSize(2,MathAbs(tp-sl)/Point);
   sl=0;
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
//                Chiusura in base al TMA 
//--------------------------------------------------------+
bool stoppedByTMA(int ot){
   double actualTMA = 0;
   if(ot==OP_BUY)  {actualTMA = iCustom(nomIndice,0,"Downloads\\TMA_Channel_End_Point",TMA_Period,0,100,TMA_K,0,1);}
   if(ot==OP_SELL) {actualTMA = iCustom(nomIndice,0,"Downloads\\TMA_Channel_End_Point",TMA_Period,0,100,TMA_K,2,1);}
   double actualPrice = MarketInfo(nomIndice,MODE_BID);
   bool result = false;
   
   if ( (ot == OP_BUY)  && (actualPrice > actualTMA) ) result = true;
   if ( (ot == OP_SELL) && (actualPrice < actualTMA) ) result = true;
   
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
   if(OrderLots()< POWER) return false; // se l'ordine è già stato ridotto, non lo riduco ulteriormente
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
   
   // arrotondo i lotti in base a quello che può accettare questo strumento
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