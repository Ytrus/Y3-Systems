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

extern double TP_Multiplier = 1; // imposta il rapporto rischio/rendimento. da 1:1 in su
extern int numberOfOrders = 3; //usato per decidere quanti ordini aprire per ogni posizione. Moltiplica anche la distanza del TP (x1, x2, x3 etc)
extern int SL_added_pips = 2; // distanza in pip da aggiungere allo SL. Lo SL è uguale al massimo(minimo) della barra precedente + questo numero di pips. Così è gestibile per ogni strumento.

extern string nameOfHistoryFile = "HA_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 3;
extern bool enablePowerLIB = true;





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
   
   
   
//-----------------enter buy order---------------------------+

   // buyConditions array
   if ((startingHour <= h) && (h < endingHour))                buyConditions[0] = true;
   if (haClose[1] > haOpen[1])                                 buyConditions[1] = true; //la barra HA precedente è BULL
   if (MathAbs(haClose[1]-haOpen[1]) > 1*Point)                buyConditions[2] = true; //la barra precedente ha + di 1 punto tra apertura e chiusura
   if ((haClose[2] < haOpen[2]) && (haClose[3] < haOpen[3]))   buyConditions[3] = true; //le due barre precedenti a quella sono entrambe BEAR
   if (nearestMin < min+tollerance)                            buyConditions[4] = true; //il minimo delle ultime 3 barre era vicino al minimo assoluto della giornata
   if (MarketInfo(nomIndice,MODE_BID) >= min)                  buyConditions[5] = true; // se il prezzo sta scendendo non devo rientrare (mi ha già buttato fuori quando ho toccato min)
   if (MarketInfo(nomIndice,MODE_BID) >= haLow[1])             buyConditions[6] = true; // idem per il minimo della barra precedente
   if (MarketInfo(nomIndice,MODE_BID) <= Low[1])               buyConditions[7] = true; // Se scende sotto al minimo della barra precedente non entro più
   if (Low[0] > min)                                           buyConditions[8] = true; // solo se la barra attuale non è anche il minimo di giornata 
   if (MarketInfo(nomIndice,MODE_SPREAD) < 2*Point)            buyConditions[9] = true; //entro solo quando lo spread è inferiore a 2
   if (existOrder(0) < 0)                                      buyConditions[10] = true; // non ho già un ordine aperto in questa direzione
   
   
   if(   //(Volume[0] == 1) &&
       (buyConditions[0]) 
      && (buyConditions[1]) 
      && (buyConditions[2]) 
      && (buyConditions[3])
      && (buyConditions[4])
      && (buyConditions[5]) 
      //&& (buyConditions[6]) 
      //&& (buyConditions[7]) 
      && (buyConditions[8]) 
      //&& (buyConditions[9]) 
      && (buyConditions[10]) 
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
     if ((isCameBack(OrderTicket()))                                          // Se ha raggiunto il primo TP e torna indietro
       ||(MarketInfo(nomIndice,MODE_BID) <= OrderStopLoss() + (1000*Point))     // Raggiunto SL
       ||(MarketInfo(nomIndice,MODE_BID) >= OrderTakeProfit() - (1000*Point))   // Raggiunto TP
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
   if (MarketInfo(nomIndice,MODE_BID) <= haHigh[1])            sellConditions[6] = true; // idem per il massimo della barra precedente
   if (MarketInfo(nomIndice,MODE_BID) >= High[1])              sellConditions[7] = true; // Se sale oltre il max della barra precedente non entro più
   if (High[0] < max)                                          sellConditions[8] = true; // solo se la barra attuale non è anche il massimo di giornata 
   if (MarketInfo(nomIndice,MODE_SPREAD) < 2*Point)            sellConditions[9] = true; // entro solo quando lo spread è inferiore a 2 punti
   if (existOrder(1) < 0 )                                     sellConditions[10] = true;// non ho già un ordine attivo in questa direzione

   if(    //(Volume[0] == 1) &&
      (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2])
      && (sellConditions[3])
      && (sellConditions[4])
      && (sellConditions[5]) 
      //&& (sellConditions[6]) 
      //&& (sellConditions[7]) 
      && (sellConditions[8]) 
      //&& (sellConditions[9]) 
      && (sellConditions[10]) 
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
     if ( (isCameBack(OrderTicket()))                                          // Se ha raggiunto il primo TP e torna indietro
       ||(MarketInfo(nomIndice,MODE_ASK) >= OrderStopLoss() - (1000*Point))     // Raggiunto SL
       ||(MarketInfo(nomIndice,MODE_ASK) <= OrderTakeProfit() + (1000*Point))   // Raggiunto TP
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
   
         takeprofit = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) - stoploss) * orx * TP_Multiplier ; //High[1] + ((High[1] - stoploss) * orx * TP_Multiplier) ;
   
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
         
         
         takeprofit = MarketInfo(nomIndice,MODE_BID) - (stoploss - MarketInfo(nomIndice,MODE_BID)) * orx * TP_Multiplier; //   Low[1] - ((stoploss - Low[1]) * orx * TP_Multiplier);
         
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

bool chk_ordersOnThisBar(int tik) 
   {
      
      //se c'è un ordine nella barra attuale è per forza l'ultimo inserito, non certo uno più vecchio
      if (OrderSelect(tik, SELECT_BY_TICKET)==true)
      {
         int shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
         
         if (shift == 0)  
            return true;   
         else
            return false;
      }
      else return false;   
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
         if ( (max_ - OrderOpenPrice() >= profit) && (MarketInfo(nomIndice,MODE_BID) <= OrderOpenPrice()) )
         {result = true; Print("Order Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         min_ = Low[iLowest(nomIndice,0,MODE_LOW,shift,0)]; //Print("isCameBack SELL: profit="+profit+" -- min_="+min_+" -- shift="+shift);
         if ((OrderOpenPrice() - min_ >= profit) && (MarketInfo(nomIndice,MODE_BID) >= OrderOpenPrice()) )
         {result = true; Print("Order Sell ", tkt, " is Coming Back: CHIUDO");}
      }
       
   }
      return result;

}
//-----------------end----------------------------------------+ 


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



//--- Restituisce il SIC attuale ----------------------------+ 
// SIC è la più vantaggiosa chiusura vista nelle ultime t barre o da quando il trade è stato aperto
double getSIC(int shift, string type)
{
   //shift: numero di giorni da guardare indietro
   //type: indica se cercare la chiusura più alta o quella più bassa e può essere "max" o "min"

   shift = shift + 1; //dato che lavoro sulla apertura della barra zero, devo guardare indietro di una barra in più.
   double max_, min_;
   double result = -1;
   int tkt = 0;
   int oshift = 0;
     
   if (type == "max") // massima chiusura vista
   {
      // se c'è un ordine aperto, prendo la sua barra come shift
      tkt = existOrder(0); //buy order
      
      if (tkt > 0)
      {
         //Print("getSIC - Esiste ordine BUY: ",tkt);
         if (OrderSelect(tkt,SELECT_BY_TICKET)==true)
         oshift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      }
      
      // dato che l'ordine potrebbe essere recente, prendo il maggiore tra 
      shift = MathMax(shift, oshift);
      
      max_ = Close[iHighest(nomIndice,0,MODE_CLOSE,shift,2)];
      {result = max_;}
   }


   if (type == "min") // minima chiusura vista
   {
      // se c'è un ordine aperto, prendo la sua barra come shift
      tkt = existOrder(1); //sell order
      
      
      if (tkt > 0)
      {
         //Print("getSIC - Esiste ordine SELL: ",tkt);
         if (OrderSelect(tkt,SELECT_BY_TICKET)==true)
         oshift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      }

      // dato che l'ordine potrebbe essere recente, prendo il maggiore tra 
      shift = MathMax(shift, oshift);
            
      min_ = Close[iLowest(nomIndice,0,MODE_CLOSE,shift,2)];
      {result = min_;}
   }
    
   return result;


}
//-----------------end----------------------------------------+ 

void drawSAR(double maxSAR_, double minSAR_)
{  
  string object_name;
  uint on = GetTickCount();
 
  // maxSAR      
  object_name = "maxSAR_"+on;
  if(ObjectFind(object_name)<0)
     {
      //--- if not found, create it
      if(ObjectCreate(object_name,OBJ_ARROW,0,Time[1],maxSAR_))
        {
         //--- set object properties
         //--- arrow code
         ObjectSet(object_name,OBJPROP_ARROWCODE,4);
         
         //--- color
         ObjectSet(object_name,OBJPROP_COLOR,DodgerBlue);
         //--- price
         ObjectSet(object_name,OBJPROP_PRICE1,maxSAR_);
         //--- time
         ObjectSet(object_name,OBJPROP_TIME1,Time[1]);
        }
     }
   else
     {
      //--- if the object exists, just modify its price coordinate
      ObjectSet(object_name,OBJPROP_PRICE1,maxSAR_);
      //--- and it's time
      ObjectSet(object_name,OBJPROP_TIME1,Time[1]);
     }   
     
  // minSAR      
  object_name = "minSAR_"+on;
  if(ObjectFind(object_name)<0)
     {
      //--- if not found, create it
      if(ObjectCreate(object_name,OBJ_ARROW,0,Time[1],minSAR_))
        {
         //--- set object properties
         //--- arrow code
         ObjectSet(object_name,OBJPROP_ARROWCODE,4);
         //--- color
         ObjectSet(object_name,OBJPROP_COLOR,clrBrown);
         //--- price
         ObjectSet(object_name,OBJPROP_PRICE1,minSAR_);
         //--- time
         ObjectSet(object_name,OBJPROP_TIME1,Time[1]);
        }
     }
   else
     {
      //--- if the object exists, just modify its price coordinate
      ObjectSet(object_name,OBJPROP_PRICE1,minSAR_);
      //--- and it's time
      ObjectSet(object_name,OBJPROP_TIME1,Time[1]);
     }        
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
            
            "\n +-----------------------------   ",
            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],
            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],
            "\n +-----------------------------   ",


            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+