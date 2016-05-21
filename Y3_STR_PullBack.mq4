//+------------------------------------------------------------------+
//|                                                    Y3_DailyP.mq4 |
//|                             Copyright 2016, Y di Matteo Parenti. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, Y3"
#property link      "https://www.y3web.it"
#property version   "1.00"
#property strict
// ============== NOTE ======================



string bot_name = "DailyP";
string nomIndice = "GBPUSD"; //sovrascritto dopo in init()

extern int SIGNATURE = 0073000;
extern string COMMENT = "Y3DailyPullBack";
extern double POWER = 20;
extern int supertrendPriod = 10;
extern double supertrendMultiplier = 1.7;
extern int protectionStartDistance = 75;
extern int protectionCloseDistance = 70;
extern bool partialCloseEnabled = false;


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
   
   if(   (supertrendUpSignal()) 
      && (!existOrder(OP_BUY))
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_BUY))
     )   
         openOrder(OP_BUY, POWER);
   
   
   // =========================================
   // ------ Close Buy Orders, if needed ------
   // =========================================

   // chiusura di TUTTI I BUY
/*   if (   ( (stoppedBySupertrend(OP_BUY)) && (cumulativeProfitIsPositive(OP_BUY)) )                  // se il superTrebd si gira e la somma dei profitti è positiva
      ) closeAllOrders(OP_BUY);
*/
     
   for(int pos=0;pos<OrdersTotal();pos++)
   {
      if( (OrderSelect(pos,SELECT_BY_POS)==false) 
      || (OrderSymbol() != nomIndice)
      || (OrderMagicNumber() != SIGNATURE)
      || (OrderType() != OP_BUY)) continue;


      // chiusura SINGOLO ordine 
      if ( 
         ( (stoppedBySupertrend(OP_BUY)) )                                                            // se il superTrend si gira e questo ordine è stato aperto SOPRA il limite superiore
         || (protector(OrderTicket(), protectionStartDistance, protectionCloseDistance))             // se ha raggiunto una certa percentuale di profitto e poi torna indietro
      ) closeOrder(OrderTicket());


      // --- chiusura parziale ---
      if (
         ( (supertrendDownSignal()) && (OrderLots()==POWER) )     // se si gira dimezzo l'ordine
      )
      
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
   
   if(   (supertrendDownSignal())
      && (!existOrder(OP_SELL))
      && (!existOpendedAndClosedOnThisBar(1))
      && (!existOrderOnThisBar(OP_SELL))
     )   
         openOrder(OP_SELL, POWER);

   
   // =========================================
   // ------ Close Sell Orders, if needed -----
   // =========================================

   // --- chiusura di TUTTI i Sell  ---
/*   if (   ( (stoppedBySupertrend(OP_SELL)) && (cumulativeProfitIsPositive(OP_SELL)) )                 // se il superTrend si gira e la somma dei profitti è positiva
      ) closeAllOrders(OP_SELL);
*/
      
   for(int pos=0;pos<OrdersTotal();pos++)
   {
      if( (OrderSelect(pos,SELECT_BY_POS)==false)
      || (OrderSymbol() != nomIndice)
      || (OrderMagicNumber() != SIGNATURE)
      || (OrderType() != OP_SELL)) continue;

      
      // chiusura SINGOLO ordine 
      if (
         ( (stoppedBySupertrend(OP_SELL))  )                                                        // se il superTrend si gira e questo ordine è stato aperto SOTTO il limite inferiore
         || (protector(OrderTicket(), protectionStartDistance, protectionCloseDistance))             // se ha raggiunto una certa percentuale di profitto e poi torna indietro
      ) closeOrder(OrderTicket());
      
      
      // --- chiusura parziale ---
      if (
         ( (supertrendUpSignal()) && (OrderLots()==POWER) )  // se si gira dimezzo l'ordine
         )
         partialClose(OrderTicket());
   }
   


   
   // screen Log
   //screenLog();
   
}
//+------------------------------------------------------------------+
//+----------------      OnTick End     -----------------------------+
//+------------------------------------------------------------------+



//-------------------------------------------------+
//    Il prezzo tocca e supera il supertrend 
//-------------------------------------------------+
bool supertrendUpSignal(){

   double actualSupertrend = iCustom(nomIndice,PERIOD_CURRENT,"Downloads\\xSuperTrend","","",supertrendPriod,supertrendMultiplier,0,0);
   double oldSupertrend = iCustom(nomIndice,PERIOD_CURRENT,"Downloads\\xSuperTrend","","",supertrendPriod,supertrendMultiplier,0,1);
   
   if( (Close[1] < actualSupertrend) && (Close[2] > oldSupertrend) ) return true;
   else return false;

}

//-------------------------------------------------+
//    Il prezzo incrocia supertrend verso basso 
//-------------------------------------------------+
bool supertrendDownSignal(){

   double actualSupertrend = iCustom(nomIndice,PERIOD_CURRENT,"Downloads\\xSuperTrend","","",supertrendPriod,supertrendMultiplier,0,0);
   double oldSupertrend = iCustom(nomIndice,PERIOD_CURRENT,"Downloads\\xSuperTrend","","",supertrendPriod,supertrendMultiplier,0,1);
   
   if( (Close[1] > actualSupertrend) && (Close[2] < oldSupertrend) ) return true;
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


//-----------------------------------------------------------------+
//       Ci sono almeno 2 ordini aperti in questa direzione
//-----------------------------------------------------------------+
bool moreThanOneOrderOpened(int ot)
{
   int total = OrdersTotal();
   int openOrders = 0;
   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY) && (OrderCloseTime() == 0) && (ot == OP_BUY) )         
         openOrders++;
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0) && (ot == OP_SELL) )         
         openOrders++;
   }
   
   if (openOrders > 1) result = true;
   
   return result;       
}





//--------------------------------------------------------+
//                Apertura di un ordine 
//--------------------------------------------------------+
bool openOrder(int ot, double sz){
   int ticket = -1;
   double tp = 0, sl = 0, prz =0;
   color c = clrBlue;
   if (ot == OP_BUY) {prz = MarketInfo(nomIndice,MODE_ASK); tp = High[iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,10,1)]; sl = Low[iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,3,1)]-2*Point;   c = clrBlue;}
   if (ot == OP_SELL){prz = MarketInfo(nomIndice,MODE_BID); tp = Low[iLowest(nomIndice,PERIOD_CURRENT,MODE_LOW,10,1)]; sl = High[iHighest(nomIndice,PERIOD_CURRENT,MODE_HIGH,3,1)]+2*Point; c = clrRed; }

   
   sl = 0;
   //sz = getSize(2,MathAbs(tp-sl)/Point);

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
//           Chiude tutti gli ordini di un tipo 
//--------------------------------------------------------+
bool closeAllOrders(int ot){
   int total = OrdersTotal();
   double price = MarketInfo(nomIndice,MODE_BID);
   color c = clrGreen;
   bool result = false;

   for(int pos=0;pos<total;pos++)
   {
      
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY) && (OrderCloseTime() == 0) && (ot == OP_BUY) ) {
         result = false;
         while(!result){
            price = MarketInfo(nomIndice,MODE_BID);
            result = OrderClose(OrderTicket(),OrderLots(),price,2,c);
            if (!result) {Print("Errore nella chiusura di un ordine BUY: "+(string)GetLastError()); Sleep(2000); RefreshRates();}
         }
         pos--;
      }
         
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0) && (ot == OP_SELL) ){
         result = false;
         while(!result){
            price = MarketInfo(nomIndice,MODE_ASK);
            result = OrderClose(OrderTicket(),OrderLots(),price,2,c);
            if (!result) {Print("Errore nella chiusura di un ordine SELL: "+(string)GetLastError()); Sleep(2000); RefreshRates();}
         }
         pos--;
      }
      
   }
   
   return true;
}
//--------------------------------------------------------+
//                Chiusura in base al SUPETREND 
//--------------------------------------------------------+
bool stoppedBySupertrend(int ot){
   double lastSupertrend = iCustom(nomIndice,PERIOD_CURRENT,"Downloads\\xSuperTrend","","",supertrendPriod,supertrendMultiplier,0,1);
   double lastClosePrice = Close[1];
   bool result = false;
   
   if ( (ot == OP_BUY)  && (lastClosePrice < lastSupertrend) ) {result = true; }
   if ( (ot == OP_SELL) && (lastClosePrice > lastSupertrend) ) {result = true; }
   
   return result;
}




//-----------------------------------------------------------------+
// La somma dei profitti è positiva? (per i BUY o per i SELL)
//-----------------------------------------------------------------+
bool cumulativeProfitIsPositive(int ot){
   int total = OrdersTotal();
   double cumulativeProfit = 0;
   bool result = false;
   
   for(int pos=0;pos<total;pos++)
   {
      
      if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
      if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_BUY) && (OrderCloseTime() == 0) && (ot == OP_BUY) )         
         cumulativeProfit += OrderProfit();
      if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == OP_SELL) && (OrderCloseTime() == 0) && (ot == OP_SELL) )         
         cumulativeProfit += OrderProfit();
   }
   
   if (cumulativeProfit > 100) result=true;
   
   return result;          
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

bool protector(int tkt,int protectionStart, int protectionClose)
{
   // protectionStart: la percentuale di profitto a cui si attiva il protettore
   // protectionClose: la percentuale che viene protetta, dopo aver raggiunto protectionStart

   int shift;
   double profit, max_, min_ = 0;
   bool result = false;
   double activationDistance = 0;
   double closeDistance = 0;
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      //se questo ordine ha visto sulla carta un profitto pari al rischio (profit), quando torna indietro lo chiudo a brake even
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      profit = MathAbs(OrderOpenPrice() - OrderTakeProfit());                    // Guardo la distanza del TP per proteggerne una percentuale
      activationDistance = NormalizeDouble(profit/100*protectionStart, Digits);  // distanza a cui iniziare a proteggere la posizione, in pips
      closeDistance = NormalizeDouble(profit/100*protectionClose, Digits);       // distanza dello stopProfit, in pips
     
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         max_ = High[iHighest(nomIndice,0,MODE_HIGH,shift,0)]; //Print("isCameBack BUY: profit="+profit+" -- max_="+max_+" -- shift="+shift);
         if ( (max_ - OrderOpenPrice() >= activationDistance) && (MarketInfo(nomIndice,MODE_BID) <= (OrderOpenPrice()+closeDistance) ) )
         {result = true; Print("Protector: Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         min_ = Low[iLowest(nomIndice,0,MODE_LOW,shift,0)]; //Print("isCameBack SELL: profit="+profit+" -- min_="+min_+" -- shift="+shift);
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