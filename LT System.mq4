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
extern int startingHour = 0; //orario di apertura da cui iniziare a verificare  massimi e minimi ed orario di inizio validit� tecnica normalmente � una o due ore pi� indietro del nostro.
extern int endingHour = 24; //orario di fine attivit� per questo strumento. Probabilmente sar� da tarare.
//extern int MA_slow = 100; //MA lenta 
extern int MA_fast = 21; //MA veloce
extern int MAChannel = 3; // periodo delle MA H e L
extern string nameOfHistoryFile = "LT_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 3;
extern bool enablePowerLIB = true;


//+------------------------------------------------------------------+


//------------------------Declarations-------------------------------+

bool tradeBuy   = false;

bool entreeBuy  = false;

bool sortieBuy  = false;

bool tradeSell  = false;

bool entreeSell = false;

bool sortieSell = false;

int ticketBuy;

int ticketSell;

double p; //order size



//variabili per determinare il dateTime esatto della barra di apertura di oggi.
datetime tm, startTime, endTime;
MqlDateTime stm;

double tollerance; // tolleranza in pip della distanza dalle medie H ed L per entrare ed uscire (all'inizio non usato)

//double nearestMax, nearestMin; //minimo e massimo delle ultime 3 barre, per sapere se il reverse � tradabile
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

  //distruggo l'array historicPips perch� altrimenti rimane pieno
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

   double fastMA, slowMA;
   int startBarOffset, shift, h;

   entreeBuy  = false;

   sortieBuy  = false;

   entreeSell = false;

   sortieSell = false;

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
   if (isPin("up"))                                            buyConditions[1] = true; // la barra precedente � una pin up
   if (MarketInfo(nomIndice,MODE_BID) > fastMA)                buyConditions[2] = true; // il prezzo � sopra alla media a veloce
   if (MarketInfo(nomIndice,MODE_BID) > High[1])               buyConditions[3] = true; // il prezzo rompe il massimo della pin...
   if (MarketInfo(nomIndice,MODE_BID) < High[1]+4*Point)       buyConditions[4] = true; // ...ma non pi� di 3 punti
   if (Close[1] > fastMA)                                       buyConditions[5] = true; // il massimo della pin � sopra la media mobile
   // il minimo
   
   
   if(//   (Volume[0] == 1)
         (buyConditions[0]) 
      && (buyConditions[1])  
      && (buyConditions[2])  
      && (buyConditions[3])  
      && (buyConditions[4])  
      && (buyConditions[5])  

   )
   {
         entreeBuy = true; 
         //Print("BUY - b:",b," - a:",a);
   }

   

//-----------------end---------------------------------------------+

 

//-----------------exit buy order---------------------------+

   
   if (OrderSelect(ticketBuy, SELECT_BY_TICKET)==true) 
   {
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // la pin � la barra precedente all'ordine
      double profit;
      profit = 2*(High[shift]-Low[shift]);
      
      if ( (MarketInfo(nomIndice,MODE_BID) > High[shift]+profit)  // se vedo un profitto pari al  rischio, chiudo
          || (MarketInfo(nomIndice,MODE_BID)<fastMA)              // se il prezzo scende sotto la media mobile veloce
          //|| (MarketInfo(nomIndice,MODE_BID)<Low[shift]-3*Point)  // se il prezzo scende sotto al minimo della pin
         )
         
      {      
          sortieBuy = true;
      }

      
   }
   
     

//-----------------end---------------------------------------------+

 

//-----------------enter sell order----------------------------+

   // sellConditions array
   if ((startingHour <= h) && (h < endingHour))                sellConditions[0] = true; // siamo negli orari consentiti
   if (isPin("down"))                                          sellConditions[1] = true; // la barra precedente � una pin down
   if (MarketInfo(nomIndice,MODE_BID) < fastMA)                sellConditions[2] = true; // siamo sotto alla media a veloce
   if (MarketInfo(nomIndice,MODE_BID) < Low[1])                sellConditions[3] = true; // il prezzo rompe il minimo della pin...
   if (MarketInfo(nomIndice,MODE_BID) > Low[1]-3*Point)        sellConditions[4] = true; // ... ma non pi� di 3 punti
   if (Close[1] < fastMA)                                        sellConditions[5] = true; // il minimo della pin � sotto la media mobile

   if(//   (Volume[0] == 1)
         (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2]) 
      && (sellConditions[3]) 
      && (sellConditions[4]) 
      && (sellConditions[5]) 


   )
   {
      entreeSell = true; 
      //Print("SELL - b:",b," - a:",a);
   }
   

//-----------------end---------------------------------------------+

 

//-----------------exit sell order ---------------------------+

   
   if (OrderSelect(ticketSell, SELECT_BY_TICKET)==true) // tentativo di protezione del profitto
   {
   
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // la pin � la barra precedente all'ordine

      profit = 2*(High[shift]-Low[shift]);

      if (
            (MarketInfo(nomIndice,MODE_BID) < Low[shift]-profit)  // se vedo un profitto pari al rischio, chiudo
            || (MarketInfo(nomIndice,MODE_BID) > fastMA ) // se il prezzo sale sopra alla media mobile veloce
            //|| (MarketInfo(nomIndice,MODE_BID) > High[shift]+3*Point ) // se il prezzo sale sopra al massimo della pin
         
         )
      {
       sortieSell = true;
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
  

   if(tradeBuy == false && tradeSell == false && entreeBuy == true)
   

   {

      stoploss   = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);

      takeprofit = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);

      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketBuy = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,"LarryWilliamStrategy_System" ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Buy-----------------+

      if(ticketBuy > 0) tradeBuy = true;

   }

   return(0);

}

//-----------------end----------------------------------------+

 

//-------------------Buy close-----------------------------------+

int fermetureBuy()

{

   bool t;

   if(tradeBuy == true && sortieBuy == true)

   {

   //------------------close ordre buy------------------------------------+
   if (OrderSelect(ticketBuy,SELECT_BY_TICKET)==true)
      double lots = OrderLots();     

   t = OrderClose(ticketBuy,lots,MarketInfo(nomIndice,MODE_BID),5,Brown);
   Print("fermetureBuy - ticketBuy ",ticketBuy);
   
  

   //-------------------confirmation du close buy--------------------------+

   if (t == true) { tradeBuy = false; addOrderToHistory(ticketBuy); ticketBuy = 0; }

   }

   return(0);

}

//-----------------end----------------------------------------+

 

//-----------------------------Sell open-----------------------+

int ouvertureSell()

{

   double stoploss, takeprofit;

  

   if(tradeSell == false && tradeBuy == false && entreeSell == true)

   {
   

      
      stoploss   = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      
      takeprofit = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);

      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketSell = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,"LarryWilliamStrategy_System" ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Sell-----------------+

      if(ticketSell > 0)tradeSell = true;

   }

   return(0);

}

//-----------------end----------------------------------------+

 

//-------------------Sell close-----------------------------------+

int fermetureSell()

{

   bool t;

   if(tradeSell == true && sortieSell == true)

   {

   //------------------close ordre Sell------------------------------------+
   if (OrderSelect(ticketSell,SELECT_BY_TICKET)==true)
      double lots = OrderLots();     

   t = OrderClose(ticketSell,lots,MarketInfo(nomIndice,MODE_ASK),5,Brown);
   Print("fermetureSell - ticketSell ",ticketSell);  

   //-------------------confirmation du close Sell--------------------------+

   if (t == true){ tradeSell = false; addOrderToHistory(ticketSell); ticketSell = 0; }

   }

   return(0);

}

//-----------------end----------------------------------------+


bool isPin(string type="up")
   {
   double mid = ((High[1]-Low[1])/2)+Low[1]; // posizione mediana della barra 1
   
   if (type == "up")
      {
      if (  (Open[1] > mid) && (Close[1] > mid) // � una pin up se � rinchiusa nella met� inferiore dell'ombra
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

            "\n TICKET BUY       : ",ticketBuy,

            "\n TICKET SELL      : ",ticketSell,
            
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