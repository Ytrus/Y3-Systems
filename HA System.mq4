//+------------------------------------------------------------------+
//| v 0.1 beta                                                       |
//|                                             http://www.y3web.net |
//| DEFAULT: DAX30 M15                                               |
//+------------------------------------------------------------------+

// DAX30 - dalle 8:00 alle 17:00 possibilmente su M10 (usando period converter se possibile) - i test li farò su M15.
// ingresso sulle barre Haiken Ashi di inversione vicine ai massimi/minimi giornalieri. Anche dopo aver fatto nuovi massimi/minimi giornalieri
// non si entra su HA (Haiken Ashi) doji. Miima distanza tra apertura e chiusura: 2 pips su DAX30.
// la tecnica è valida anche su ITA40, SP500, Eurostoxx
// TP = 10 pips
// SL = 10 pips
// In seguito si faranno tentativi con valori diversi


//--------Index name------+

string nomIndice = "GER30"; //sovrascritto dopo in init()
 

//--------number of lots to trade--------------+
extern int SIGNATURE = 1431416;
extern double POWER = 0.1;
extern int startingHour = 6; //orario di apertura da cui iniziare a verificare  massimi e minimi ed orario di inizio validità tecnica normalmente è una o due ore più indietro del nostro.
extern int endingHour = 15; //orario di fine attività per questo strumento. Probabilmente sarà da tarare.
extern int MA_slow = 21; //MA lenta
extern int MA_fast = 6; //MA veloce
extern string nameOfHistoryFile = "HA_System_HST_";
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


// imposto delle variabili per prendere apertura, chiusura, massimo e minimo dell'hHaiken_Ashi
//--- the number of indicator buffer for storage Open
#define  HA_OPEN     2
//--- the number of the indicator buffer for storage High
#define  HA_HIGH     1
//--- the number of indicator buffer for storage Low
#define  HA_LOW      0
//--- the number of indicator buffer for storage Close
#define  HA_CLOSE    3

//variabili per determinare il dateTime esatto della barra di apertura di oggi.
datetime tm, startTime, endTime;
MqlDateTime stm;

double tollerance; // tolleranza in pip della distanza dai massimi e minimi per entrare sui reverse

double haOpen[4], haClose[4], haHigh[4], haLow[4]; // arrays con i valori delle Haiken Ashi
double nearestMax, nearestMin; //minimo e massimo delle ultime 3 barre, per sapere se il reverse è tradabile
double min, max; //minimo e massimo di giornata, aggiornati ad ogni nuova barra

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
   if (ObjectCreate(NULL,"maxRangeBox",OBJ_RECTANGLE,0,0,0,0,0) == false) 
      Alert("Errore nella creazione di maxRangeBox: "+GetLastError());
   else
      ObjectSet("maxRangeBox",OBJPROP_COLOR,DodgerBlue);
      

   if (ObjectCreate(NULL,"minRangeBox",OBJ_RECTANGLE,0,0,0,0,0) == false) 
      Alert("Errore nella creazione di minRangeBox: "+GetLastError());
   else
      ObjectSet("minRangeBox",OBJPROP_COLOR,Maroon);
   
   
   
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
   ObjectDelete(ChartID(),"maxRangeBox");
   ObjectDelete(ChartID(),"minRangeBox");
   
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

   double a, b;
   int startBarOffset, highestBarShift, lowestBarShift, h;

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
   
   
   // DEBUG verifico di avere individuato la barra giusta
   //if (ObjectCreate(NULL,"StartTradingBarArrow",OBJ_ARROW_DOWN,0,startTime,High[startBarOffset]+20*Point) == false)
   //   Alert("Errore nella creazione dell'arrow. "+GetLastError());
   //if (Volume[0] == 1) Alert("Barra di inzio giornata: H "+High[startBarOffset]+" - O "+Open[startBarOffset]+" - C "+Close[startBarOffset]+" - L"+Low[startBarOffset]);





   if (Volume[0] == 1)
   {
      // Determino massimi e minimi di oggi per trovare i punti di inversione
      highestBarShift = iHighest(nomIndice,0,MODE_HIGH,startBarOffset,0);
      lowestBarShift  = iLowest(nomIndice,0,MODE_LOW,startBarOffset,0);
      
      //Recupero i valori di prezzo del massimo e del minimo di giornata
      max = High[highestBarShift];
      min = Low[lowestBarShift];
      
      // minimo e massimo visti nelle ultime 5 barre (per sapere se poter entrare sul reverse)
      nearestMax = High[iHighest(nomIndice,0,MODE_HIGH,5,0)];
      nearestMin = Low[iLowest(nomIndice,0,MODE_LOW,5,0)];
   }

   // la distanza accettabile dai massimi e minimi del giorno per entrare la ricavo dall'ATR 14.
   // le posizioni long potranno aver raggiunto un prezzo superiore al minimo di giornata pari alla grandezza di tollerance.
   tollerance = MathRound(iATR(nomIndice,0,100,0)/3*2);

   if (Volume[0] == 1) {
      //aggiorno i rettangoli che partono dalle barre maggiore e minore ed arrivano ad ora
      ObjectSet("maxRangeBox",OBJPROP_TIME1,iTime(nomIndice,0,highestBarShift)); ObjectSet("maxRangeBox",OBJPROP_PRICE1,max); //max
      ObjectSet("maxRangeBox",OBJPROP_TIME2,TimeCurrent()); ObjectSet("maxRangeBox",OBJPROP_PRICE2,max-tollerance); //max
   
      //aggiorno i rettangoli che partono dalle barre maggiore e minore ed arrivano ad ora
      ObjectSet("minRangeBox",OBJPROP_TIME1,iTime(nomIndice,0,lowestBarShift)); ObjectSet("minRangeBox",OBJPROP_PRICE1,min); //max
      ObjectSet("minRangeBox",OBJPROP_TIME2,TimeCurrent()); ObjectSet("minRangeBox",OBJPROP_PRICE2,min+tollerance); //max
   }
   

   h = Hour(); // ora attuale
   

// ------------------ Attribuzione Haiken Ashi --------------------

   for (int i=1;i<4;i++)
   {  // High e Low delle Heiken Ashi non funzionano come i prezzi
      // High può essere inferiore a low, nel qual caso è il low e la barra è rossa.
      // Quando invece High è > Low la barra è bianca.
      haOpen[i]  = iCustom(nomIndice,0,"Heiken Ashi",HA_OPEN,i);
      haClose[i] = iCustom(nomIndice,0,"Heiken Ashi",HA_CLOSE,i);
      haHigh[i]  = MathMax(iCustom(nomIndice,0,"Heiken Ashi",HA_HIGH,i),iCustom(nomIndice,0,"Heiken Ashi",HA_LOW,i));
      haLow[i]   = MathMin(iCustom(nomIndice,0,"Heiken Ashi",HA_HIGH,i),iCustom(nomIndice,0,"Heiken Ashi",HA_LOW,i));
   }
   
   
   
//-----------------enter buy order---------------------------+

   // buyConditions array
   if ((startingHour <= h) && (h < endingHour))                buyConditions[0] = true;
   if (haClose[1] > haOpen[1])                                 buyConditions[1] = true; //la barra HA precedente è BULL
   if (MathAbs(haClose[1]-haOpen[1]) > 1*Point)                buyConditions[2] = true; //la barra precedente ha + di 1 punto tra apertura e chiusura
   if ((haClose[2] < haOpen[2]) && (haClose[3] < haOpen[3]))   buyConditions[3] = true; //le due barre precedenti a quella sono entrambe BEAR
   if (nearestMin < min+tollerance)                            buyConditions[4] = true; //il minimo delle ultime 3 barre era vicino al minimo assoluto della giornata
   if (MarketInfo(nomIndice,MODE_BID) >= min)                  buyConditions[5] = true; // se il prezzo sta scendendo non devo rientrare (mi ha già buttato fuori quando ho toccato min)
   if (MarketInfo(nomIndice,MODE_BID) >= haLow[1])             buyConditions[6] = true; // idem per il minimo della barra precedente
   if (MarketInfo(nomIndice,MODE_BID) <= (High[1]+Low[1])/2)   buyConditions[7] = true; // il prezzo di ingresso deve essere inferiore o uguale al centro della barra precedente.
   if (iMA(nomIndice,0,MA_fast,0,MODE_EMA,PRICE_MEDIAN,1) > iMA(nomIndice,0,MA_slow,0,MODE_EMA,PRICE_MEDIAN,1))  buyConditions[8] = true; //solo se la media a 6 è sopra la media a 21 (trend up)
   if (MarketInfo(nomIndice,MODE_SPREAD) < 2*Point)            buyConditions[9] = true; //entro solo quando lo spread è inferiore a 2
   
   if(   //(Volume[0] == 1) &&
       (buyConditions[0]) 
      && (buyConditions[1]) 
      && (buyConditions[2]) 
      && (buyConditions[3])
      //&& (buyConditions[4])
      && (buyConditions[5]) 
      && (buyConditions[6]) 
      && (buyConditions[7]) 
      && (buyConditions[8]) 
      && (buyConditions[9]) 

      //&& (MathAbs(haOpen[1]-haClose[1]) > MathAbs(haHigh[1]-haLow[1])/2 ) //il corpo deve essere maggiore alla metà dell'ombra
   )
   {
         entreeBuy = true; 
         //Print("BUY - b:",b," - a:",a);
   }

   

//-----------------end---------------------------------------------+

 

//-----------------exit buy order---------------------------+

   
   if (OrderSelect(ticketBuy, SELECT_BY_TICKET)==true) 
   {

   
      //Mordi e fuggi: se vedo 10 pip di guadagno li prendo. Idem lo stop. (PERDE E BASTA)
      //if ((MarketInfo(nomIndice,MODE_BID)<=OrderOpenPrice()-10*Point) || (MarketInfo(nomIndice,MODE_BID)>=OrderOpenPrice()+10*Point))
      
      double TP_atr;
      TP_atr = OrderOpenPrice() + MathRound(iATR(nomIndice,0,100,0));
      
      if (//(MarketInfo(nomIndice,MODE_BID) < min ) // sescendo sotto al min di giornata
          (MarketInfo(nomIndice,MODE_BID) < (haLow[1]-2*Point)) // se scendo sotto al minimo della barra HA precedente
          //|| (MarketInfo(nomIndice,MODE_BID) >= TP_atr) //se il prezzo raggiunge ATR(20) di profitto
         //|| (MathAbs(haOpen[1]-haClose[1]) < MathAbs(haHigh[1]-haLow[1])/2 ) // se la barra precedente ha il corpo inferiore alla metà dell'ombra
         )
      {      
          sortieBuy = true;
      }
      
      
      
  
      //if (maxProfit>3*atr && c>0)//se ho visto un profitto maggiore di tre volte atr....
      //{
      //   if(MarketInfo(nomIndice,MODE_BID)<=OrderOpenPrice()) sortieBuy = true;//brake even
      //}
      
      
      //if (maxProfit>=6*atr && c>0)//non permetto al sistema di perdere tutto. 
      //{
      //   if (MarketInfo(nomIndice,MODE_BID) <= OrderOpenPrice()+atr) sortieBuy = true;//Proteggo un profitto pari ad atr
      //}      
      
   }
   
     

//-----------------end---------------------------------------------+

 

//-----------------enter sell order----------------------------+

   // sellConditions array
   if ((startingHour <= h) && (h < endingHour))                sellConditions[0] = true; 
   if (haClose[1] < haOpen[1])                                 sellConditions[1] = true; //la barra HA precedente è BEAR
   if (MathAbs(haClose[1]-haOpen[1]) > 1*Point)                sellConditions[2] = true; //la barra precedente ha + di 1 punto tra apertura e chiusura
   if ((haClose[2] > haOpen[2]) && (haClose[3] > haOpen[3]))   sellConditions[3] = true; //le due barre precedenti a quella sono entrambe BULL
   if (nearestMax > max-tollerance)                            sellConditions[4] = true; //il massimo delle ultime 5 barre era vicino al massimo assoluto della giornata
   if (MarketInfo(nomIndice,MODE_BID) <= max)                  sellConditions[5] = true; // se il prezzo sta salendo non devo rientrare (mi ha già buttato fuori quando ho toccato max)
   if (MarketInfo(nomIndice,MODE_BID) <= haHigh[1])            sellConditions[6] = true; // idem per il massimo della barra precedente
   if (MarketInfo(nomIndice,MODE_BID) >= (High[1]+Low[1])/2)   sellConditions[7] = true; // il prezzo di ingresso deve essere superiore o uguale al centro della barra precedente.
   if ( iMA(nomIndice,0,MA_fast,0,MODE_EMA,PRICE_MEDIAN,1) < iMA(nomIndice,0,MA_slow,0,MODE_EMA,PRICE_MEDIAN,1))  sellConditions[8] = true; //solo se la media a 6 è sotto la media a 21 (trend up)
   if (MarketInfo(nomIndice,MODE_SPREAD) < 2*Point)           sellConditions[9] = true; //entro solo quando lo spread è inferiore a 2 punti

   if(    //(Volume[0] == 1) &&
      (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2])
      && (sellConditions[3])
      //&& (sellConditions[4])
      && (sellConditions[5]) 
      && (sellConditions[6]) 
      && (sellConditions[7]) 
      && (sellConditions[8]) 
      && (sellConditions[9]) 
      
      //&& (MathAbs(haOpen[1]-haClose[1]) > MathAbs(haHigh[1]-haLow[1])/2 ) //il corpo deve essere maggiore alla metà dell'ombra
   )
   {
      entreeSell = true; 
      //Print("SELL - b:",b," - a:",a);
   }
   

//-----------------end---------------------------------------------+

 

//-----------------exit sell order ---------------------------+

   
   if (OrderSelect(ticketSell, SELECT_BY_TICKET)==true) // tentativo di protezione del profitto
   {
   
      //Mordi e fuggi: se vedo 10 pip di guadagno li prendo. Idem lo stop. (PERDE E BASTA)
      //if ((MarketInfo(nomIndice,MODE_ASK)<=OrderOpenPrice()-10*Point) || (MarketInfo(nomIndice,MODE_ASK)>=OrderOpenPrice()+10*Point))

      TP_atr = OrderOpenPrice() - MathRound(iATR(nomIndice,0,100,0));
      
      if (//(MarketInfo(nomIndice,MODE_BID) > max ) // se salgo sopra al max di giornata
            (MarketInfo(nomIndice,MODE_BID) > (haHigh[1]+2*Point)) // se salgo sopra al massimo della barra HA precedente
         //|| (MarketInfo(nomIndice,MODE_BID) <= TP_atr) //se il prezzo raggiunge ATR(20) di profitto
         //|| (MathAbs(haOpen[1]-haClose[1]) < MathAbs(haHigh[1]-haLow[1])/2 ) // se la barra precedente ha il corpo inferiore alla metà dell'ombra
         )      {
       sortieSell = true;
      }


      
      
      //if (maxProfit>3*atr && c>0) //se ho visto un profitto maggiore di tre volte atr....
      //{
      //   if(MarketInfo(nomIndice,MODE_BID)>=OrderOpenPrice()) sortieSell = true;//brake even         
      //}
      

      //if (maxProfit>=6*atr && c>0)//non permetto al sistema di perdere tutto. 
      //{
      //   if (MarketInfo(nomIndice,MODE_BID) >= OrderOpenPrice()-atr) sortieSell = true;//Proteggo un profitto del 50%
      //}
   

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

     

      ticketBuy = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,"Y3_HA_System" ,SIGNATURE,0,MediumBlue);

     

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

     

      ticketSell = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,"Y3_HA_System" ,SIGNATURE,0,MediumBlue);

     

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
            "\n Tollerance       : ",tollerance,
            
            //"\n nearestMax       : ",nearestMax, 
            //"\n nearestMin       : ",nearestMin, 
            
            //"\n min       : ",min, 
            //"\n max       : ",max, 

         
            "\n +-----------------------------   ",
            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],buyConditions[2],buyConditions[3],buyConditions[4],buyConditions[5],buyConditions[6],buyConditions[7],buyConditions[8],buyConditions[9],
            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],sellConditions[2],sellConditions[3],sellConditions[4],sellConditions[5],sellConditions[6],sellConditions[7],sellConditions[8],sellConditions[9],
            "\n +-----------------------------   ",

            
            //"\n haOpen[1]       : ",haOpen[1],
            //"\n haClose[1]       : ",haClose[1],
            //"\n haHigh[1]       : ",haHigh[1],
            //"\n haLow[1]       : ",haLow[1],

            //"\n haOpen[1]       : ",haOpen[2],
            //"\n haClose[1]       : ",haClose[2],
            //"\n haHigh[1]       : ",haHigh[2],
            //"\n haLow[1]       : ",haLow[2],            

            //"\n haOpen[1]       : ",haOpen[3],
            //"\n haClose[1]       : ",haClose[3],
            //"\n haHigh[1]       : ",haHigh[3],
            //"\n haLow[1]       : ",haLow[3],            
            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+