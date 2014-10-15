//+------------------------------------------------------------------+
//| v 0.1 beta                                                       |
//|                                             http://www.y3web.net |
//| DEFAULT: Da testare, nessun default al momento                   |
//+------------------------------------------------------------------+

// NOTE
//
//
//
//

//--------Index name------+

string nomIndice = "GER30"; //sovrascritto dopo in init()
 

//--------number of lots to trade--------------+
extern int SIGNATURE = 1431417;
extern double POWER = 0.1;
extern int startingHour = 6; //orario di apertura da cui iniziare a verificare  massimi e minimi ed orario di inizio validità tecnica normalmente è una o due ore più indietro del nostro.
extern int endingHour = 15; //orario di fine attività per questo strumento. Probabilmente sarà da tarare.
extern int MA_slow = 21; //MA lenta
extern int MA_fast = 3; //MA veloce
extern int MAChannel = 3; // periodo delle MA H e L
extern string nameOfHistoryFile = "LarryWilliamStrategy_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 3;
extern bool enablePowerLIB = false;


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

   double fastMA, slowMA, channel_H, channel_L;
   int startBarOffset, h;

   entreeBuy  = false;

   sortieBuy  = false;

   entreeSell = false;

   sortieSell = false;

   ArrayInitialize(buyConditions,false);   //Array buyConditions per debuggare
   ArrayInitialize(sellConditions,false);   //Array sellConditions per debuggare

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
   
   slowMA = iMA(nomIndice,0,MA_slow,0,MODE_EMA,PRICE_MEDIAN,0);
   fastMA = iMA(nomIndice,0,MA_fast,0,MODE_EMA,PRICE_MEDIAN,0);
   channel_H = iEnvelopes(nomIndice,0,MAChannel,MODE_SMA,0,PRICE_OPEN,0.50,1,0); // MODE_UPPER
   channel_L = iEnvelopes(nomIndice,0,MAChannel,MODE_SMA,0,PRICE_OPEN,0.50,2,0); // MODE_LOWER


   // la distanza accettabile dai massimi e minimi del canale la ricavo dall'ATR 14.
   // tollerance = MathRound(iATR(nomIndice,0,100,0)/3*2);

   h = Hour(); // ora attuale   
   
   
//-----------------enter buy order---------------------------+

   // buyConditions array
   if ((startingHour <= h) && (h < endingHour))                buyConditions[0] = true; // siamo negli orari consentiti
   if (fastMA > slowMA)                                        buyConditions[1] = true; // siamo in trend up (fast > slow)
   if (MarketInfo(nomIndice,MODE_BID) <= channel_L)            buyConditions[2] = true; // il prezzo tocca il canale inferiore
   if (MarketInfo(nomIndice,MODE_BID) > slowMA)                buyConditions[3] = true; // il prezzo deve essere sopra a slowMA
   
   if(   //(Volume[0] == 1) &&
       (buyConditions[0]) 
      && (buyConditions[1]) 
      && (buyConditions[2]) 
      && (buyConditions[3]) 

   )
   {
         entreeBuy = true; 
         //Print("BUY - b:",b," - a:",a);
   }

   

//-----------------end---------------------------------------------+

 

//-----------------exit buy order---------------------------+

   
   if (OrderSelect(ticketBuy, SELECT_BY_TICKET)==true) 
   {
      
      
      if ( //(MarketInfo(nomIndice,MODE_BID) >= channel_H ) // se tocco il canale inferiore
          (fastMA<slowMA)                               // se la media veloce scende sotto alla lenta, il trend è compromesso
         )
         
      {      
          sortieBuy = true;
      }

      
   }
   
     

//-----------------end---------------------------------------------+

 

//-----------------enter sell order----------------------------+

   // sellConditions array
   if ((startingHour <= h) && (h < endingHour))                sellConditions[0] = true; // siamo negli orari consentiti
   if (fastMA < slowMA)                                        sellConditions[1] = true; // siamo in trend down (fast < slow)
   if (MarketInfo(nomIndice,MODE_BID) >= channel_H)            sellConditions[2] = true; // il prezzo tocca il canale superiore
   if (MarketInfo(nomIndice,MODE_BID) < slowMA)                sellConditions[3] = true; // il prezzo deve essere sotto a slowMA

   if(    //(Volume[0] == 1) &&
      (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2])
      && (sellConditions[3])

   )
   {
      entreeSell = true; 
      //Print("SELL - b:",b," - a:",a);
   }
   

//-----------------end---------------------------------------------+

 

//-----------------exit sell order ---------------------------+

   
   if (OrderSelect(ticketSell, SELECT_BY_TICKET)==true) // tentativo di protezione del profitto
   {
   
      if (//(MarketInfo(nomIndice,MODE_BID) <= channel_L ) // se tocco il canale superiore esco
          (fastMA>slowMA)                              // se fastMA sale sopra a slowMA il trend short è compromesso
         )      {
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