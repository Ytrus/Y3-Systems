//+------------------------------------------------------------------+
//| v 0.1 beta                                                       |
//|                                             http://www.y3web.net |
//| DEFAULT: H4 XAUUSD                                               |
//| 65% in 10 mesi da gennaio a ottobre 2014  (capitale 3.000)       |
//+------------------------------------------------------------------+

// NOTE
// 
//
//
//

//--------Index name------+

string nomIndice = "GER30"; //sovrascritto dopo in init()
 

//--------number of lots to trade--------------+
extern int SIGNATURE = 1431418;
extern double POWER = 30;
extern int startingHour = 0; //orario di apertura da cui iniziare a verificare  massimi e minimi ed orario di inizio validità tecnica normalmente è una o due ore più indietro del nostro.
extern int endingHour = 24; //orario di fine attività per questo strumento. Probabilmente sarà da tarare.
//extern int MA_slow = 100; //MA lenta 
extern int MA_fast = 21; //MA veloce
extern int MAChannel = 3; // periodo delle MA H e L
extern string nameOfHistoryFile = "LT_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 3;
extern bool enablePowerLIB = true;


//+------------------------------------------------------------------+


//------------------------Declarations-------------------------------+

bool tradeBuy[3];

bool entreeBuy[3];

bool sortieBuy[3];

bool tradeSell[3];

bool entreeSell[3];

bool sortieSell[3];

int ticketBuy[3];

int ticketSell[3];

double p; //order size



//variabili per determinare il dateTime esatto della barra di apertura di oggi.
datetime tm, startTime, endTime;
MqlDateTime stm;

double tollerance; // tolleranza in pip della distanza dalle medie H ed L per entrare ed uscire (all'inizio non usato)

//double nearestMax, nearestMin; //minimo e massimo delle ultime 3 barre, per sapere se il reverse è tradabile
//double min, max; //minimo e massimo di giornata, aggiornati ad ogni nuova barra

bool buyConditions[10]; 
bool sellConditions[10]; 


//+--------------- Include ------------------------+

#include  <Y3_POWER_LIB.mqh>

//+----------------------- end --------------------+

 

//+------------------------------------------------------------------+

//| expert initialization function                                   |

//+------------------------------------------------------------------+

int init()

  {

   //metto il simbolo attuale nella variabile, per poter utilizzare il programma su ogni simbolo
   nomIndice = Symbol();
   
   
   initY3_POWER_LIB(nameOfHistoryFile,SIGNATURE,Y3_POWER_LIB_maPeriod,enablePowerLIB);

   //Creo i rettangoli usato per la visualizzazione dei massimi e quello per i minimi
   /*if (ObjectCreate(NULL,"maxRangeBox",OBJ_RECTANGLE,0,0,0,0,0) == false) 
      Alert("Errore nella creazione di maxRangeBox: "+GetLastError());
   else
      ObjectSet("maxRangeBox",OBJPROP_COLOR,DodgerBlue);
      

   if (ObjectCreate(NULL,"minRangeBox",OBJ_RECTANGLE,0,0,0,0,0) == false) 
      Alert("Errore nella creazione di minRangeBox: "+GetLastError());
   else
      ObjectSet("minRangeBox",OBJPROP_COLOR,Maroon);
   */
   
   
//----

   return(0);

  }

//+------------------------------------------------------------------+

//| expert deinitialization function                                 |

//+------------------------------------------------------------------+

int deinit()

  {

//----

  //distruggo l'array historicPips perchè altrimenti rimane pieno
  ArrayFree(historicPips);


   //Elimino i rettangoli usati per la visualizzazione dei massimi e quello per i minimi
   //ObjectDelete(ChartID(),"maxRangeBox");
   //ObjectDelete(ChartID(),"minRangeBox");
   
//----

   return(0);

  }

//+------------------------------------------------------------------+

//| expert start function                                            |

//+------------------------------------------------------------------+

int start()

  {

//----


   paramD1();

   ouvertureBuy();

   fermetureBuy();

   ouvertureSell();

   fermetureSell();

   commentaire();



//----

   return(0);

  }

//+---------------------end-----------------------------+

 

//------------------------Subroutine parameters--------------------------+

int paramD1()

{ 

   double fastMA, slowMA, profit;
   int startBarOffset, shift, h;

   ArrayInitialize(entreeBuy,false);
   ArrayInitialize(sortieBuy,false);
   ArrayInitialize(entreeSell,false);
   ArrayInitialize(sortieSell,false);
      

   ArrayInitialize(buyConditions,false);   //Array buyConditions per debuggare
   ArrayInitialize(sellConditions,false);   //Array sellConditions per debuggare


   // ========================================
   // TODO: verificare se ci sono degli ordini, per poter inserire i TakeProfit
   // Se non ci sono e le variabili (tradeBuy & tradeSell) dicono di si, azzerare le variabili (false).
   //loop history and get orders of this robot
   



   // ===============================================================================
   // determino le date e gli orari delle barre di start e di end del trading system   
   // ===============================================================================
   tm = TimeCurrent();
   
   TimeToStruct(tm,stm);
   
   stm.hour = startingHour;   stm.min = 0;   stm.sec = 0;
   startTime = StructToTime(stm);

   stm.hour = endingHour;   stm.min = 0;   stm.sec = 0;
   endTime = StructToTime(stm);
   
   startBarOffset = iBarShift(nomIndice,0,startTime,false) + 1; //offset della barra di inizio giornata
   
   //slowMA = iMA(nomIndice,0,MA_slow,0,MODE_EMA,PRICE_MEDIAN,0);
   fastMA = iMA(nomIndice,0,MA_fast,0,MODE_EMA,PRICE_MEDIAN,0);



   // la distanza accettabile dai massimi e minimi del canale la ricavo dall'ATR 14.
   // tollerance = MathRound(iATR(nomIndice,0,100,0)/3*2);

   h = Hour(); // ora attuale   
   
   
//-----------------enter buy order---------------------------+

   // buyConditions array
   if ((startingHour <= h) && (h < endingHour))                buyConditions[0] = true; // siamo negli orari consentiti
   if (isPin("up"))                                            buyConditions[1] = true; // la barra precedente è una pin up
   if (MarketInfo(nomIndice,MODE_BID) > fastMA)                buyConditions[2] = true; // il prezzo è sopra alla media a veloce
   if (MarketInfo(nomIndice,MODE_BID) > High[1]+3*Point)       buyConditions[3] = true; // il prezzo rompe il massimo della pin...
   if (MarketInfo(nomIndice,MODE_BID) < High[1]+6*Point)       buyConditions[4] = true; // ...ma non più di 3 punti
   if (Close[1] > fastMA)                                      buyConditions[5] = true; // il massimo della pin è sopra la media mobile
   if (High[0] < High[1]+20*Point)                             buyConditions[6] = true; // il massimo di oggi non è oltre 10 pips del massimo della pin. Significa che sono già entrato ed uscito!
   // il minimo
   
   
   if(//   (Volume[0] == 1)
         (buyConditions[0]) 
      && (buyConditions[1])  
      && (buyConditions[2])  
      && (buyConditions[3])  
      && (buyConditions[4])  
      && (buyConditions[5])  
      && (buyConditions[6])  

   )
   {
         // attivo tutti gli ordini
         entreeBuy[0] = true;
         entreeBuy[1] = true;
         entreeBuy[2] = true;
         //Print("BUY - b:",b," - a:",a);
   }

   

//-----------------end---------------------------------------------+

 

//-----------------exit buy orders---------------------------+

   // primo ordine
   if (OrderSelect(ticketBuy[0], SELECT_BY_TICKET)==true) 
   {
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // la pin è la barra precedente all'ordine
      profit = (High[shift]-Low[shift]);
      
      if ( (MarketInfo(nomIndice,MODE_BID) > High[shift]+profit)  // se vedo un profitto pari al  rischio, chiudo il primo ordine
          || (MarketInfo(nomIndice,MODE_BID)<fastMA)              // se il prezzo scende sotto la media mobile veloce
          //|| (MarketInfo(nomIndice,MODE_BID)<Low[shift]-3*Point)  // se il prezzo scende sotto al minimo della pin
         )
         
      {      
          sortieBuy[0] = true;
      }
      
   }

   // secondo ordine
   if (OrderSelect(ticketBuy[1], SELECT_BY_TICKET)==true) 
   {
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // la pin è la barra precedente all'ordine
      profit = (High[shift]-Low[shift]);
      
      if ( (MarketInfo(nomIndice,MODE_BID) > High[shift]+2*profit)  // se vedo un profitto pari al  rischio, chiudo il primo ordine
          || (MarketInfo(nomIndice,MODE_BID)<fastMA)              // se il prezzo scende sotto la media mobile veloce
          //|| (MarketInfo(nomIndice,MODE_BID)<Low[shift]-3*Point)  // se il prezzo scende sotto al minimo della pin
         )
         
      {      
          sortieBuy[1] = true;
      }
      
      if (ticketBuy[0]==0) //il primo ordine è già stato chiuso a profitto
         {
            if (MarketInfo(nomIndice,MODE_BID) <= OrderOpenPrice()) //se torno a pareggio, chiudo
            {sortieBuy[1] = true;}
         }
      
      
      
   }
   
   // terzo ordine
   if (OrderSelect(ticketBuy[2], SELECT_BY_TICKET)==true) 
   {
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // la pin è la barra precedente all'ordine
      profit = (High[shift]-Low[shift]);
      
      if ( (MarketInfo(nomIndice,MODE_BID) > High[shift]+3*profit)  // se vedo un profitto pari al  rischio, chiudo il primo ordine
          || (MarketInfo(nomIndice,MODE_BID)<fastMA)              // se il prezzo scende sotto la media mobile veloce
          //|| (MarketInfo(nomIndice,MODE_BID)<Low[shift]-3*Point)  // se il prezzo scende sotto al minimo della pin
         )
         
      {      
          sortieBuy[2] = true;
      }

      if (ticketBuy[0]==0) //il primo ordine è già stato chiuso a profitto
         {
            if (MarketInfo(nomIndice,MODE_BID) <= OrderOpenPrice()) //se torno a pareggio, chiudo
            {sortieBuy[2] = true;}
         }
      
   }
   
//-----------------end---------------------------------------------+

 

//-----------------enter sell order----------------------------+

   // sellConditions array
   if ((startingHour <= h) && (h < endingHour))                sellConditions[0] = true; // siamo negli orari consentiti
   if (isPin("down"))                                          sellConditions[1] = true; // la barra precedente è una pin down
   if (MarketInfo(nomIndice,MODE_BID) < fastMA)                sellConditions[2] = true; // siamo sotto alla media a veloce
   if (MarketInfo(nomIndice,MODE_BID) < Low[1]-3*Point)        sellConditions[3] = true; // il prezzo rompe il minimo della pin...
   if (MarketInfo(nomIndice,MODE_BID) > Low[1]-6*Point)        sellConditions[4] = true; // ... ma non più di 6 punti
   if (Close[1] < fastMA)                                      sellConditions[5] = true; // il minimo della pin è sotto la media mobile
   if (Low[0]>Low[1]-20*Point)                                 sellConditions[6] = true; // il minimo di oggi è oltre 10 pips sotto alla pin. Significa che sono già entrato ed uscito!

   if(//   (Volume[0] == 1)
         (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2]) 
      && (sellConditions[3]) 
      && (sellConditions[4]) 
      && (sellConditions[5]) 
      && (sellConditions[6]) 


   )
   {
      // attivo tutti gli ordini
      entreeSell[0] = true; 
      entreeSell[1] = true; 
      entreeSell[2] = true; 
      //Print("SELL - b:",b," - a:",a);
   }
   

//-----------------end---------------------------------------------+

 

//-----------------exit sell order ---------------------------+

   //primo ordine
   if (OrderSelect(ticketSell[0], SELECT_BY_TICKET)==true) 
   {
   
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // la pin è la barra precedente all'ordine

      profit = (High[shift]-Low[shift]);

      if (
            (MarketInfo(nomIndice,MODE_BID) < Low[shift]-profit)  // se vedo un profitto pari al rischio, chiudo
            || (MarketInfo(nomIndice,MODE_BID) > fastMA ) // se il prezzo sale sopra alla media mobile veloce
            //|| (MarketInfo(nomIndice,MODE_BID) > High[shift]+3*Point ) // se il prezzo sale sopra al massimo della pin
         
         )
      {
       sortieSell[0] = true;
      }

   }


   //secondo ordine
   if (OrderSelect(ticketSell[1], SELECT_BY_TICKET)==true) 
   {
   
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // la pin è la barra precedente all'ordine

      profit = (High[shift]-Low[shift]);

      if (
            (MarketInfo(nomIndice,MODE_BID) < Low[shift]-2*profit)  // se vedo un profitto pari al rischio, chiudo
            || (MarketInfo(nomIndice,MODE_BID) > fastMA ) // se il prezzo sale sopra alla media mobile veloce
            //|| (MarketInfo(nomIndice,MODE_BID) > High[shift]+3*Point ) // se il prezzo sale sopra al massimo della pin
         
         )
      {
       sortieSell[1] = true;
      }

      if (ticketSell[0]==0) //il primo ordine è già stato chiuso a profitto
         {
            if (MarketInfo(nomIndice,MODE_BID) >= OrderOpenPrice()) //se torno a pareggio, chiudo
            {sortieSell[1] = true;}
         }

   }


   //terzo ordine
   if (OrderSelect(ticketSell[2], SELECT_BY_TICKET)==true) 
   {
   
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // la pin è la barra precedente all'ordine

      profit = (High[shift]-Low[shift]);

      if (
            (MarketInfo(nomIndice,MODE_BID) < Low[shift]-3*profit)  // se vedo un profitto pari al rischio, chiudo
            || (MarketInfo(nomIndice,MODE_BID) > fastMA ) // se il prezzo sale sopra alla media mobile veloce
            //|| (MarketInfo(nomIndice,MODE_BID) > High[shift]+3*Point ) // se il prezzo sale sopra al massimo della pin
         
         )
      {
       sortieSell[2] = true;
      }

      if (ticketSell[0]==0) //il primo ordine è già stato chiuso a profitto
         {
            if (MarketInfo(nomIndice,MODE_BID) >= OrderOpenPrice()) //se torno a pareggio, chiudo
            {sortieSell[2] = true;}
         }

   }

//-----------------end---------------------------------------------+

 

 

   return(0);

}

// +-----------------------end Subroutine parameters---------------------------------+

 

//------------------------------Buy open-----------------------+

int ouvertureBuy()

{
   double stoploss, takeprofit;
  
   // primo ordine
   if(tradeBuy[0] == false && tradeSell[0] == false && entreeBuy[0] == true)
   {

      stoploss   = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      takeprofit = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));
      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

      ticketBuy[0] = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,"LarryWilliamStrategy_System" ,SIGNATURE,0,MediumBlue);

      //------------------confirmation du passage ordre Buy-----------------+

      if(ticketBuy[0] > 0) tradeBuy[0] = true;

   }


   // secondo ordine
   if(tradeBuy[1] == false && tradeSell[1] == false && entreeBuy[1] == true)
   {

      stoploss   = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      takeprofit = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));
      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

      ticketBuy[1] = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,"LarryWilliamStrategy_System" ,SIGNATURE,0,MediumBlue);

      //------------------confirmation du passage ordre Buy-----------------+

      if(ticketBuy[1] > 0) tradeBuy[1] = true;

   }


   // terzo ordine
   if(tradeBuy[2] == false && tradeSell[2] == false && entreeBuy[2] == true)
   {

      stoploss   = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      takeprofit = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));
      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

      ticketBuy[2] = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,"LarryWilliamStrategy_System" ,SIGNATURE,0,MediumBlue);

      //------------------confirmation du passage ordre Buy-----------------+

      if(ticketBuy[2] > 0) tradeBuy[2] = true;

   }

   return(0);
}

//-----------------end----------------------------------------+

 

//-------------------Buy close-----------------------------------+

int fermetureBuy()

{
   bool t;
   double lots = 0;
   
   
   // primo ordine
   if(tradeBuy[0] == true && sortieBuy[0] == true)

   {

   //------------------close ordre buy------------------------------------+
   if (OrderSelect(ticketBuy[0],SELECT_BY_TICKET)==true)
      lots = OrderLots();     

   t = OrderClose(ticketBuy[0],lots,MarketInfo(nomIndice,MODE_BID),5,Brown);
   Print("fermetureBuy - ticketBuy ",ticketBuy[0]);

   //-------------------confirmation du close buy--------------------------+

   if (t == true) { tradeBuy[0] = false; addOrderToHistory(ticketBuy[0]); ticketBuy[0] = 0; }

   }

   // secondo ordine
   if(tradeBuy[1] == true && sortieBuy[1] == true)

   {

   //------------------close ordre buy------------------------------------+
   if (OrderSelect(ticketBuy[1],SELECT_BY_TICKET)==true)
      lots = OrderLots();     

   t = OrderClose(ticketBuy[1],lots,MarketInfo(nomIndice,MODE_BID),5,Brown);
   Print("fermetureBuy - ticketBuy ",ticketBuy[1]);

   //-------------------confirmation du close buy--------------------------+

   if (t == true) { tradeBuy[1] = false; addOrderToHistory(ticketBuy[1]); ticketBuy[1] = 0; }

   }

   // terzo ordine
   if(tradeBuy[2] == true && sortieBuy[2] == true)

   {

   //------------------close ordre buy------------------------------------+
   if (OrderSelect(ticketBuy[2],SELECT_BY_TICKET)==true)
      lots = OrderLots();     

   t = OrderClose(ticketBuy[2],lots,MarketInfo(nomIndice,MODE_BID),5,Brown);
   Print("fermetureBuy - ticketBuy ",ticketBuy[2]);

   //-------------------confirmation du close buy--------------------------+

   if (t == true) { tradeBuy[2] = false; addOrderToHistory(ticketBuy[2]); ticketBuy[2] = 0; }

   }

   return(0);
}

//-----------------end----------------------------------------+

 

//-----------------------------Sell open-----------------------+

int ouvertureSell()

{
   double stoploss, takeprofit;
  
   //primo ordine
   if(tradeSell[0] == false && tradeBuy[0] == false && entreeSell[0] == true)

   {
      stoploss   = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      takeprofit = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));
      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

      ticketSell[0] = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,"LarryWilliamStrategy_System" ,SIGNATURE,0,MediumBlue);

      //------------------confirmation du passage ordre Sell-----------------+

      if(ticketSell[0] > 0)tradeSell[0] = true;

   }

   //secondo ordine
   if(tradeSell[1] == false && tradeBuy[1] == false && entreeSell[1] == true)

   {
      stoploss   = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      takeprofit = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));
      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

      ticketSell[1] = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,"LarryWilliamStrategy_System" ,SIGNATURE,0,MediumBlue);

      //------------------confirmation du passage ordre Sell-----------------+

      if(ticketSell[1] > 0)tradeSell[1] = true;

   }

   //terzo ordine
   if(tradeSell[2] == false && tradeBuy[2] == false && entreeSell[2] == true)

   {
      stoploss   = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      takeprofit = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));
      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

      ticketSell[2] = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,"LarryWilliamStrategy_System" ,SIGNATURE,0,MediumBlue);

      //------------------confirmation du passage ordre Sell-----------------+

      if(ticketSell[2] > 0)tradeSell[2] = true;

   }

   return(0);

}

//-----------------end----------------------------------------+

 

//-------------------Sell close-----------------------------------+

int fermetureSell()

{
   bool t;
   double lots = 0;
   
   //primo ordine
   if(tradeSell[0] == true && sortieSell[0] == true)

   {
   //------------------close ordre Sell------------------------------------+
   if (OrderSelect(ticketSell[0],SELECT_BY_TICKET)==true)
      lots = OrderLots();     

   t = OrderClose(ticketSell[0],lots,MarketInfo(nomIndice,MODE_ASK),5,Brown);
   Print("fermetureSell - ticketSell ",ticketSell[0]);  

   //-------------------confirmation du close Sell--------------------------+

   if (t == true){ tradeSell[0] = false; addOrderToHistory(ticketSell[0]); ticketSell[0] = 0; }
   }


   //secondo ordine
   if(tradeSell[1] == true && sortieSell[1] == true)

   {
   //------------------close ordre Sell------------------------------------+
   if (OrderSelect(ticketSell[1],SELECT_BY_TICKET)==true)
      lots = OrderLots();     

   t = OrderClose(ticketSell[1],lots,MarketInfo(nomIndice,MODE_ASK),5,Brown);
   Print("fermetureSell - ticketSell ",ticketSell[1]);  

   //-------------------confirmation du close Sell--------------------------+

   if (t == true){ tradeSell[1] = false; addOrderToHistory(ticketSell[1]); ticketSell[1] = 0; }
   }


   //terzo ordine
   if(tradeSell[2] == true && sortieSell[2] == true)

   {
   //------------------close ordre Sell------------------------------------+
   if (OrderSelect(ticketSell[2],SELECT_BY_TICKET)==true)
      lots = OrderLots();     

   t = OrderClose(ticketSell[2],lots,MarketInfo(nomIndice,MODE_ASK),5,Brown);
   Print("fermetureSell - ticketSell ",ticketSell[2]);  

   //-------------------confirmation du close Sell--------------------------+

   if (t == true){ tradeSell[2] = false; addOrderToHistory(ticketSell[2]); ticketSell[2] = 0; }
   }

   return(0);
}

//-----------------end----------------------------------------+


bool isPin(string type="up")
   {
   double mid = ((High[1]-Low[1])/2)+Low[1]; // posizione mediana della barra 1
   
   if (type == "up")
      {
      if (  (Open[1] > mid) && (Close[1] > mid) // è una pin up se è rinchiusa nella metà inferiore dell'ombra
         && (Low[2]>Low[1]) && (Low[3]>Low[1])  // se almeno le due barre precedenti hanno minimi superiori alla pin
         ) return(true);      
      else return(false);
      }
   
   
   if (type == "down")
      {
      if ( (Open[1] < mid) && (Close[1] < mid) 
         && (High[2]< High[1] && High[3] < High[1]) // se almeno le due barre precedenti hanno massimi inferiori alla pin
         ) return(true);      
      else return(false);
      }   
   
   else return(false);
   
   }



//-------------------prints------------------------------+

int commentaire()

   {

   string dj;
   dj = Day()+ " / " + Month() + "   " + Hour() + " : " + Minute()+ " : " + Seconds();


    Comment( "\n +--------------------------------------------------------+\n EXPERT : ",nomIndice,

            "\n DATE : ", dj,

          

            "\n +--------------------------------------------------------+\n   ",

            "\n TICKET BUY       : ",ticketBuy[0],

            "\n TICKET SELL      : ",ticketSell[0],
            
            "\n TRADES           : ",ArraySize(historicPips),
            
            "\n LAST TRADE PIPS  : ",historicPips[ArraySize(historicPips)-1],
            
            "\n POWER            : ",POWER,
         
            "\n SPREAD            : ",MarketInfo(nomIndice,MODE_SPREAD),
            
            "\n Now              : ",TimeToStr(tm,TIME_DATE|TIME_MINUTES),
            "\n Inizio           : ",TimeToStr(startTime,TIME_DATE|TIME_MINUTES),
            "\n Fine             : ",TimeToStr(endTime,TIME_DATE|TIME_MINUTES),
         
            "\n +-----------------------------   ",
            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],buyConditions[2],
            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],sellConditions[2],
            "\n +-----------------------------   ",

            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+