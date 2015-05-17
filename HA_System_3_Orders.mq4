//+------------------------------------------------------------------+
//| v 0.1 beta                                                       |
//|                                              http://www.y3web.it |
//| DEFAULT: DA TESTARE                                              |
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
extern int SIGNATURE = 0018000;
extern string COMMENT = "HA";
extern double POWER = 20; //default per GER30 con 8.000 euro
extern bool usePercentageRisk = false;
extern string info_p = "Se usePercentageRisk = true: POWER è la % equity da rishiare ad ogni trade. Altrimenti POWER = Lotti per ordine.";
extern int startingHour = 6; //orario di apertura da cui iniziare a verificare  massimi e minimi ed orario di inizio validità tecnica normalmente è una o due ore più indietro del nostro.
extern int endingHour = 17; //orario di fine attività per questo strumento. Probabilmente sarà da tarare.

extern double TP_Multiplier = 1; // imposta il rapporto rischio/rendimento. da 1:1 in su su TUTTI gli ordini
extern double TP_Paolone_Multiplier = 2; // moltiplicatore degli ordini dalla parte giusta della media di bollinger
extern int numberOfOrders = 3; //usato per decidere quanti ordini aprire per ogni posizione. Moltiplica anche la distanza del TP (x1, x2, x3 etc)
extern int SL_added_pips = 2; // distanza in pip da aggiungere allo SL. Lo SL è uguale al massimo(minimo) della barra precedente + questo numero di pips. Così è gestibile per ogni strumento.

extern string nameOfHistoryFile = "HA_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 3;
extern bool enablePowerLIB = true;
extern bool enableAdaptive_ma = false;
extern bool enableRiskManagement = false;
extern bool enableProfitProtection = false;
extern bool enableAutoProfit = false;



//+------------------------------------------------------------------+


//------------------------Declarations-------------------------------+

bool tradeBuy   = false;

bool entreeBuy  = false;

int sortieBuy  = 0;

bool tradeSell  = false;

bool entreeSell = false;

int sortieSell = 0;

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


bool buyConditions[20]; 
bool sellConditions[20]; 

double atr, ARC, maxSAR, minSAR;   




//+--------------- Include ------------------------+

#include  <Y3_POWER_LIB.mqh>

// ------ esperimenti col messagebox -------
//#import "user32.dll"
//   int MessageBoxA(int Ignore, string Caption, string Title, int Icon);
//#import
//#include <WinUser32.mqh>
// --------- fine esperimenti ------------------
//+----------------------- end --------------------+

 

//+------------------------------------------------------------------+

//| expert initialization function                                   |

//+------------------------------------------------------------------+

int init()

  {

   //metto il simbolo attuale nella variabile, per poter utilizzare il programma su ogni simbolo
   nomIndice = Symbol();
   
   // inizializzo la powerLib
   initY3_POWER_LIB(nameOfHistoryFile,SIGNATURE,Y3_POWER_LIB_maPeriod,enablePowerLIB, enableAdaptive_ma);
   
   
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

//   fermetureBuy();

   ouvertureSell();

//   fermetureSell();

   commentaire();
//----

   return(0);

  }

//+---------------------end-----------------------------+

 

//------------------------Subroutine parameters--------------------------+

int paramD1()

{ 

   int startBarOffset, highestBarShift, lowestBarShift, h;   

   entreeBuy  = false;
   
   entreeSell = false;
     
   ArrayInitialize(buyConditions,false);   //Array buyConditions per debuggare
   ArrayInitialize(sellConditions,false);  //Array sellConditions per debuggare

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
   tollerance = iATR(nomIndice,0,100,0)/3*2;

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
   
      double lowerBand = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_LOWER,0);
      double upperband = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_UPPER,0);
   
//-----------------enter buy order---------------------------+

   // buyConditions array
   if ((startingHour <= h) && (h < endingHour))                buyConditions[0] = true;
   if (haClose[1] > haOpen[1])                                 buyConditions[1] = true; //la barra HA precedente è BULL
   if (MathAbs(haClose[1]-haOpen[1]) > 1*Point)                buyConditions[2] = true; //la barra precedente ha + di 1 punto tra apertura e chiusura
   if ((haClose[2] < haOpen[2]) && (haClose[3] < haOpen[3]))   buyConditions[3] = true; //le due barre precedenti a quella sono entrambe BEAR
   if (nearestMin < min+tollerance)                            buyConditions[4] = true; //il minimo delle ultime 3 barre era vicino al minimo assoluto della giornata
   if (MarketInfo(nomIndice,MODE_BID) >= min)                  buyConditions[5] = true; // se il prezzo sta scendendo non devo rientrare (mi ha già buttato fuori quando ho toccato min)
   if (MarketInfo(nomIndice,MODE_BID) < upperband)             buyConditions[6] = true; // non devo essere oltre la banda superiore
   if (MarketInfo(nomIndice,MODE_BID) <= Low[1])               buyConditions[7] = true; // Se scende sotto al minimo della barra precedente non entro più
   if (Low[0] > min)                                           buyConditions[8] = true; // solo se la barra attuale non è anche il minimo di giornata 
   if (!existOrderOnThisBar(0))                                buyConditions[9] = true; // se NON ho un ordine già aperto in questa barra (apre un solo ordine per ogni direzione)
   if (existOrder(0) < 0)                                      buyConditions[10] = true; // non ho già un ordine aperto in questa direzione (apre un solo ordine per direzione)
   
   
   if(   //(Volume[0] == 1) &&
       (buyConditions[0]) 
      && (buyConditions[1]) 
      && (buyConditions[2]) 
      && (buyConditions[3])
      && (buyConditions[4])
      && (buyConditions[5]) 
      && (buyConditions[6]) 
      //&& (buyConditions[7]) 
      && (buyConditions[8]) 
      && (buyConditions[9]) 
      //&& (buyConditions[10]) 
      //&& (MathAbs(haOpen[1]-haClose[1]) > MathAbs(haHigh[1]-haLow[1])/2 ) //il corpo deve essere maggiore alla metà dell'ombra
   )
   {
         entreeBuy = true; 
         //Print("BUY - b:",b," - a:",a);
   }

   
//-----------------end---------------------------------------------+




//-----------------exit buy orders---------------------------+
// dato che posso avere più ordini da gestire, li scorro uno per uno e valuto se vanno chiusi.
// quando ne trovo uno da chiudere setto la variabile sortieBuy = ticket.
// TIP: per usare SL e TP fissi, basta fissarli a 100 Points in più di quello che dovrebbero essere e poi chiuderli qui quando li raggiungono con 100 Points di differenza.
// ES. SL = 1.700, lo imposto a 1.800 nell'ordine (1.700 + 100*Point). Qui verifico se ha raggiunto prezzo SL (1.800 - 100*Point) = 1.700 e nel caso lo chiudo.
// Idem per il TP
// la procedura fermetureBuy(ticket) chiuderà l'ordine azzerando poi la variabile sortieBuy = 0
// se non ce la fa devo ripassare lo stesso ticket a fermetureBuy, finchè ce la fa.

//scorrere gli ordini per vedere se uno va chiuso
for(int pos=0;pos<OrdersTotal();pos++)
    {
     if( (OrderSelect(pos,SELECT_BY_POS)==false)
     || (OrderSymbol() != nomIndice)
     || (OrderMagicNumber() != SIGNATURE)
     || (OrderType() != 0)) continue;
     
     // Print("Trovato Ordine Buy da controllare : ",OrderTicket());
     
     //clausole di chiusura
     if ((profitProtection(OrderTicket()))                                     // Se ha raggiunto ATR14 e torna indietro
       || (isCameBack(OrderTicket()))                                           // se ha raggiunto il primo target e torna indietro
       || (riskManagement(OrderTicket()))                                      // se tocco una banda di bollinger opposta
       ||(MarketInfo(nomIndice,MODE_BID) <= OrderStopLoss() + (1000*Point))    // Raggiunto SL
       ||(MarketInfo(nomIndice,MODE_BID) >= OrderTakeProfit() - (1000*Point))  // Raggiunto TP
       //|| (autoProfit(OrderTicket()))                                          // TP adattivo con Bollinger
        )
     {
      sortieBuy = OrderTicket();       
      Print("Trovato Ordine Buy da chiudere: ",OrderTicket());

      fermetureBuy(OrderTicket());
     }

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
   if (MarketInfo(nomIndice,MODE_BID) > lowerBand)            sellConditions[6] = true; // non devo essere oltre la banda inferiore
   if (MarketInfo(nomIndice,MODE_BID) >= High[1])              sellConditions[7] = true; // Se sale oltre il max della barra precedente non entro più
   if (High[0] < max)                                          sellConditions[8] = true; // solo se la barra attuale non è anche il massimo di giornata 
   if (!existOrderOnThisBar(1))                                sellConditions[9] = true; // se NON ho un ordine già aperto in questa barra (apre più ordini in ogni direzione)
   if (existOrder(1) < 0 )                                     sellConditions[10] = true;// non ho già un ordine attivo in questa direzione (apre un solo ordine per direzione)

   if(    //(Volume[0] == 1) &&
      (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2])
      && (sellConditions[3])
      && (sellConditions[4])
      && (sellConditions[5]) 
      && (sellConditions[6]) 
      //&& (sellConditions[7]) 
      && (sellConditions[8]) 
      && (sellConditions[9]) 
      //&& (sellConditions[10]) 
      //&& (MathAbs(haOpen[1]-haClose[1]) > MathAbs(haHigh[1]-haLow[1])/2 ) //il corpo deve essere maggiore alla metà dell'ombra
   )
   {
      entreeSell = true; 
      //Print("SELL - b:",b," - a:",a);
   }
   
//-----------------end---------------------------------------------+
 
//-----------------exit sell orders---------------------------+


//scorrere gli ordini per vedere se uno va chiuso
for(pos=0;pos<OrdersTotal();pos++)
    {
     if( (OrderSelect(pos,SELECT_BY_POS)==false)
     || (OrderSymbol() != nomIndice)
     || (OrderMagicNumber() != SIGNATURE)
     || (OrderType() != 1)) continue;
     
     //Print("Trovato Ordine Sell da controllare : ",OrderTicket());
     
     //clausole di chiusura
     if ( (profitProtection(OrderTicket()))                                     // Se ha raggiunto ATR14 e torna indietro
       || (isCameBack(OrderTicket()))                                           // se ha raggiunto il primo target e torna indietro
       || (riskManagement(OrderTicket()))                                      // se tocco una banda di bollinger opposta
       ||(MarketInfo(nomIndice,MODE_ASK) >= OrderStopLoss() - (1000*Point))     // Raggiunto SL
       ||(MarketInfo(nomIndice,MODE_ASK) <= OrderTakeProfit() + (1000*Point))   // Raggiunto TP
       //|| (autoProfit(OrderTicket()))                                          // TP adattivo con Bollinger
       )
     {
      sortieSell = OrderTicket();       
      Print("Trovato Ordine Sell da chiudere: ",OrderTicket());

      fermetureSell(OrderTicket());
     }

    }
   

//-----------------end---------------------------------------------+




   return(0);

}

// +-----------------------end Subroutine parameters---------------------------------+

 

//------------------------------Buy open-----------------------+

int ouvertureBuy()

{

   double stoploss, takeprofit, size;
  

   
   // per aprire più ordini uso la variabile numberOfOrders
   for (int orx=1;orx<=numberOfOrders;orx++)
   {
      if(entreeBuy == true)

      {  
         
         stoploss   = (min - (SL_added_pips*Point));
   
         //TP variabile in base alla posizione rispetto alla media di bollinger
         double middleBand = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,0);

         if ( MarketInfo(nomIndice,MODE_BID) > middleBand ) 
            {takeprofit = MarketInfo(nomIndice,MODE_ASK) + TP_Paolone_Multiplier*(MarketInfo(nomIndice,MODE_ASK) - stoploss) * orx * TP_Multiplier ;}
         else
            {takeprofit = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) - stoploss) * orx * TP_Multiplier ;}


         //TP originale
         //takeprofit = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) - stoploss) * orx * TP_Multiplier ; //High[1] + ((High[1] - stoploss) * orx * TP_Multiplier) ;
   
         stoploss   = NormalizeDouble(stoploss-1000*Point ,MarketInfo(nomIndice,MODE_DIGITS));
        
         takeprofit = NormalizeDouble(takeprofit+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
         
         size = getSize(POWER, MathAbs((MarketInfo(nomIndice,MODE_ASK) - stoploss)) - 1000 * Point  );
   
         ticketBuy = OrderSend(nomIndice,OP_BUY,setPower(size),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,MediumBlue);
   
        
   
         //------------------confirmation du passage ordre Buy-----------------+
   
         if(ticketBuy > 0) 
            {if (orx == numberOfOrders) 
               {tradeBuy = true; 
                  bool mailRessult = SendMail("HA System ha aperto "+ orx +" posizioni BUY", "Nessuna informazione aggiuntiva.");
                  if (mailRessult == false) Print("Errore durante invio email BUY: "+ GetLastError());
               }
            }
         else
            {orx--;}
      }

   }

   return(0);

}

//-----------------end----------------------------------------+

 
//-------------------Buy close-----------------------------------+

int fermetureBuy(int tkt)

{
   bool t;
   double lots = 0;
   
  
   if(tkt > 0)

   {

   //------------------close ordre buy------------------------------------+
   if (OrderSelect(tkt,SELECT_BY_TICKET)==true)
      lots = OrderLots();     

   t = OrderClose(tkt,lots,MarketInfo(nomIndice,MODE_BID),5,Brown);
   Print("fermetureBuy - ticketBuy ",tkt);

   //-------------------confirmation du close buy--------------------------+

   if (t == true) {sortieBuy = 0; addOrderToHistory(tkt); ticketBuy = 0; }

   }

   return(0);
}

//-----------------end----------------------------------------+



//-----------------------------Sell open-----------------------+

int ouvertureSell()

{

   double stoploss, takeprofit, size;

  
   // per aprire più ordini uso la variabile numberOfOrders
   for (int orx=1;orx<=numberOfOrders;orx++)
   {
      if(entreeSell == true)
   
      {
         
         stoploss   = (max + (SL_added_pips*Point));
         
         
         //TP variabile in base alla posizione rispetto alla media di bollinger
         double middleBand = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,0);

         if ( MarketInfo(nomIndice,MODE_BID) < middleBand ) 
            {takeprofit = MarketInfo(nomIndice,MODE_BID) - TP_Paolone_Multiplier*(stoploss - MarketInfo(nomIndice,MODE_BID)) * orx * TP_Multiplier;}
         else
            {takeprofit = MarketInfo(nomIndice,MODE_BID) - (stoploss - MarketInfo(nomIndice,MODE_BID)) * orx * TP_Multiplier;}


         // TP originale
         //takeprofit = MarketInfo(nomIndice,MODE_BID) - (stoploss - MarketInfo(nomIndice,MODE_BID)) * orx * TP_Multiplier; //   Low[1] - ((stoploss - Low[1]) * orx * TP_Multiplier);
         
         stoploss   = NormalizeDouble(stoploss+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
   
         takeprofit = NormalizeDouble(takeprofit-1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
         



         size = getSize(POWER, MathAbs((MarketInfo(nomIndice,MODE_BID) - stoploss)) - 1000*Point);
   
         ticketSell = OrderSend(nomIndice,OP_SELL,setPower(size),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,Purple);
   
        
   
         //------------------confirmation du passage ordre Sell-----------------+
   
         if(ticketSell > 0)
            {Print("Inserito ordine "+orx+" di "+numberOfOrders+".");
            if (orx == numberOfOrders) 
               {tradeSell = true; 
                  bool mailRessult = SendMail("HA System ha aperto "+ orx +" posizioni SELL", "Nessuna informazione aggiuntiva.");
                  if (mailRessult == false) Print("Errore durante invio email SELL: "+ GetLastError());
               }
            }
         else
            {orx--; } //fallito inserimento, porto indietro il counter per riprovare
      }
   }
   
   return(0);

}

//-----------------end----------------------------------------+


//-------------------Buy close-----------------------------------+

int fermetureSell(int tkt)

{
   bool t;
   double lots = 0;
   
  
   if(tkt > 0)

   {

   //------------------close ordre buy------------------------------------+
   if (OrderSelect(tkt,SELECT_BY_TICKET)==true)
      lots = OrderLots();     

   t = OrderClose(tkt,lots,MarketInfo(nomIndice,MODE_ASK),5,Brown);
   Print("fermetureBuy - ticketSell ",tkt);

   //-------------------confirmation du close buy--------------------------+

   if (t == true) {sortieSell = 0; addOrderToHistory(tkt); ticketSell = 0;}

   }

   return(0);
}

//-----------------end----------------------------------------+





//------- VERIFICA ESISTENZA ORDINI APERTI ----------+

int existOrder(int ot) 
   {
      // ot = orderType: 0 = buy; 1 = sell
      int total = OrdersTotal();
      
      for(int pos=0;pos<total;pos++)
      {
         if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
         if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == 0) && (OrderCloseTime() == 0) && (ot == 0) )         
         return OrderTicket();
         if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == 1) && (OrderCloseTime() == 0) && (ot == 1) )         
         return OrderTicket();
      }
      
      return -1;    

   
   }
//-----------------end----------------------------------------+ 


//------- VERIFICA ESISTENZA ORDINI IN QUESTA BARRA ----------+

bool existOrderOnThisBar(int ot) 
   {
      bool result = false;
      
      int total = OrdersTotal();
      
      for(int pos=0;pos<total;pos++)
      {
         if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
         if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == 0) && (OrderCloseTime() == 0) && (ot == 0) && (iBarShift(nomIndice,0,OrderOpenTime(),false) == 0) )         
         {return true;}
         if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == 1) && (OrderCloseTime() == 0)&& (ot == 1)  && (iBarShift(nomIndice,0,OrderOpenTime(),false)== 0) )         
         return true;
      }
      
      return result;    
      
   }
//-----------------end----------------------------------------+ 


//--- Verifica se un ordine torna indietro dopo aver visto un certo profitto ----------------------------+ 

bool profitProtection(int tkt)
{

   //se la funzione è disattivata, esco prima di iniziare
   if (enableProfitProtection == false) return false;
   
   int shift;
   double minProfitTarget, maxPaperProfit, protectedProfit, hiddener = 0;
   bool result = false;
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      //se questo ordine ha visto sulla carta un profitto pari ad ATR14 della barra di apertura, sposto lo SL a protezione del 10% del guadagno visto
      //in seguito, se il profitto supera 20 volte il guadagno dello Stop Profit, sposto lo stop profit al 10% del profitto visto
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      minProfitTarget = 2*NormalizeDouble(iATR(nomIndice,0,14,shift),MarketInfo(nomIndice,MODE_DIGITS));  // il profitto che cerco all'inizio è ATR(14)
      
          
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         
         maxPaperProfit = ( High[iHighest(nomIndice,0,MODE_HIGH,shift,0)] - OrderOpenPrice() ); 
         protectedProfit = NormalizeDouble(maxPaperProfit/10, MarketInfo(nomIndice,MODE_DIGITS));
         
      
         if ( (maxPaperProfit >= minProfitTarget) && (MarketInfo(nomIndice,MODE_BID) <= OrderOpenPrice()+protectedProfit) )
         {result = true; Print("profitProtection: BUY order ", tkt, " CHIUDERE");}
      
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         maxPaperProfit = ( OrderOpenPrice() - Low[iLowest(nomIndice,0,MODE_LOW,shift,0)]); 
         protectedProfit = NormalizeDouble( maxPaperProfit/10, MarketInfo(nomIndice,MODE_DIGITS) );
         
         if ( (maxPaperProfit >= minProfitTarget) && (MarketInfo(nomIndice,MODE_BID) >= OrderOpenPrice() - protectedProfit ) )
         {result = true; Print("profitProtection: SELL order ", tkt, " CHIUDERE");}
      }
       
   }
      return result;

}
//-----------------end----------------------------------------+ 



//--- Verifica se un ordine torna indietro dopo aver visto un certo profitto ----------------------------+ 

bool isCameBack(int tkt)
{

   int shift;
   double profit, max_, min_, hiddener = 0;
   bool result = false;
   hiddener = 1000*Point; // gli SL sono mascheratti
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      //se questo ordine ha visto sulla carta un profitto pari al rischio (profit), quando torna indietro lo chiudo a brake even
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      profit = MathAbs(OrderOpenPrice() - OrderStopLoss()) - hiddener;  // tutti gli ordini di un gruppo hanno lo stesso rischio, che è uguale al primo TP
      
     
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         max_ = High[iHighest(nomIndice,0,MODE_HIGH,shift,0)]; //Print("isCameBack BUY: profit="+profit+" -- max_="+max_+" -- shift="+shift);
         if ( (max_ - OrderOpenPrice() >= profit) && (MarketInfo(nomIndice,MODE_BID) <= (OrderOpenPrice()+2*Point) ) )
         {result = true; Print("Order Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         min_ = Low[iLowest(nomIndice,0,MODE_LOW,shift,0)]; //Print("isCameBack SELL: profit="+profit+" -- min_="+min_+" -- shift="+shift);
         if ((OrderOpenPrice() - min_ >= profit) && (MarketInfo(nomIndice,MODE_BID) >= (OrderOpenPrice()-2*Point) ) )
         {result = true; Print("Order Sell ", tkt, " is Coming Back: CHIUDO");}
      }
       
   }
      return result;

}
//-----------------end----------------------------------------+ 




//--- Risk management, per ridurre le perdite quando non si vede un profitto sufficiente ----------------------------+ 

bool riskManagement(int tkt)
{

   //se la funzione è disattivata, esco prima di iniziare
   if (enableRiskManagement == false) return false;

   int shift;
   double lowerLimit, higherLimit;
   bool result = false;
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      //se il prezzo va nella direzione sbagliata fino a toccare la barra di bollinger opposta, lo chiudo
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);

      lowerLimit = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_LOWER,0);
      higherLimit = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_UPPER,0);
      
          
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
               
         if (MarketInfo(nomIndice,MODE_BID) <= lowerLimit )
         {result = true; Print("riskManagement: BUY order ", tkt, " CHIUDERE");}
      
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         
         if ( MarketInfo(nomIndice,MODE_BID) >= higherLimit )
         {result = true; Print("riskManagement: SELL order ", tkt, " CHIUDERE");}
      }
       
   }
      return result;

}



bool autoProfit(int tkt){
   // restituisce true se il trade è da chiudere
   
   //se la funzione è disattivata, esco prima di iniziare
   if (enableAutoProfit == false) return false;
   
   // questa funzione gestisce il TP
   // verifica se il prezzo è uguale o migliore del TP
   // se lo è controlla la media di bollinger: se è in guadagno prosegue, altrimenti chiude il trade al TP
   // se la media è in guadagno, allora verifica se la barra precedente attraversa la banda di bollinger.
   // se la attraversa non chiude il trade a meno che non torni sulla media di bollinger
   // se non la attraversa chiude la posizione
   
   
   //TODO: verificare se ha senso chiudere la posizione quando si raggiunge il TP con la media in perdita
   
   int shift;
   double max_, min_, bid, tp; // massimo e minimo dal momento dell'ordine, bid, tp(reale)
   double lowerLimit[2], medianLimit[2], upperLimit[2]; // i valori delle 3 bande di bollinger
   bool result = false;
   int hiddener = 1000;
   
   // il prezzo attuale sul grafico (bid)
   bid = MarketInfo(nomIndice,MODE_BID);
   
   // le bande di bollinger
   lowerLimit[0] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_LOWER,0);
   medianLimit[0] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,0);
   upperLimit[0] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_UPPER,0);
   lowerLimit[1] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_LOWER,1);
   medianLimit[1] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,1);
   upperLimit[1] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_UPPER,1);

   // shift della barra dell'ordine
   shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true){   
      
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         // take profit fisico (reale) di questo ordine
         tp = OrderTakeProfit()-hiddener*Point;

         // massimo visto finora
         max_ = High[iHighest(nomIndice,0,MODE_HIGH,shift,0)]; 
            
         if ((bid >= tp ) || (max_ > tp) ){ //siamo a TP o oltre, oppure siamo stati a TP o oltre, 
            
            //if (medianLimit[0] < OrderOpenPrice()) {Print("autoProfit:(BUY "+tkt+") raggiunto TP con media in perdita"); return true;} // se siamo a TP con la media in perdita, prendo il profitto (da verificare se ha senso o no)
            
            //se sono qui, siognifica che la media è a pareggio o in guadagno, proseguo
            
            // se la barra precedente non ha raggiunto la banda di bollinger, non stiamo salendo forte, chiudo
            if ((High[1] < upperLimit[1]) && (High[0] < upperLimit[0]) && (High[0]<High[1]) ) {Print("autoProfit:(BUY "+tkt+") barra precedente non tocca bollinger"); return true;}
            
            //se sono qui, la barra precedente tocca la banda superiore di bollinger
            // quindi chiudo solo se tocco la media
            if (bid <= medianLimit[0]) {Print("autoProfit:(BUY "+tkt+") tornato alla media di bollinger"); return true;}
            
            }
            
            
         }
      

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {

         // take profit fisico (reale) di questo ordine
         tp = OrderTakeProfit()+hiddener*Point;
         
         // minimo visto finora
         min_ = Low[iLowest(nomIndice,0,MODE_LOW,shift,0)]; 
            
         if ((bid <= tp ) || (min_ < tp) ){ //siamo a TP o oltre, oppure siamo stati a TP o oltre, 
            
            //if (medianLimit[0] > OrderOpenPrice()) {Print("autoProfit:(SELL "+tkt+") raggiunto TP con media in perdita"); return true;} // se siamo a TP con la media in perdita, prendo il profitto (da verificare se ha senso o no)
            
            //se sono qui, siognifica che la media è a pareggio o in guadagno, proseguo
            
            // se la barra precedente non ha raggiunto la banda di bollinger, non stiamo scendendo forte, chiudo
            if ((Low[1] > lowerLimit[1]) && (Low[0] > lowerLimit[0]) && (Low[0] > Low[1]) ){Print("autoProfit:(SELL "+tkt+") barra precedente non tocca bollinger"); return true;}
            
            //se sono qui, la barra precedente tocca la banda inferiore di bollinger
            // quindi chiudo solo se tocco la media
            if (bid >= medianLimit[0]) {Print("autoProfit:(SELL "+tkt+") tornato alla media di bollinger"); return true;}
            
            }
            
            
         }
    }
    
    return false;
}




//--------------- SIZE AUTOMATICA ----------------------------+ 
double getSize(int risk, double distance)
{
   double equity = AccountEquity();
   double amountRisked = equity/100*risk;
   double finalSize = 0;
   double minLot = MarketInfo(nomIndice,MODE_MINLOT);
   
   distance = distance/Point; //la distanza deve sempre essere un intero
   
   amountRisked = MathRound(amountRisked/numberOfOrders);
   finalSize = amountRisked/distance;
   
   minLot = minLot * 100;
   
   finalSize = finalSize*minLot; // dovrebbe normalizzare la dimensione in base al tipo di strumento
   
   finalSize = amountRisked/(MarketInfo(nomIndice,MODE_LOTSIZE)*distance);
   
   if (nomIndice == "GER30")    finalSize = finalSize*10;
   
   if (minLot == 1) finalSize = NormalizeDouble(finalSize, 2);
   if (minLot == 10) finalSize = NormalizeDouble(finalSize, 1);
   if (minLot == 100) finalSize = NormalizeDouble(finalSize, 0);
   
   
   Print("getSize() - Risk="+risk+" - Distamce="+distance+" - amountRisked="+amountRisked+" - finalSize="+finalSize+" - MODE_MINLOT="+MarketInfo(nomIndice,MODE_MINLOT));
   if (usePercentageRisk == true) 
      return finalSize;
   else
      return POWER;
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
            
            "\n +-----------------------------   ",
            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],
            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],
            "\n +-----------------------------   ",


            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+