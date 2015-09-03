//+------------------------------------------------------------------+
//| v 0.1 beta                                                       |
//|                                              http://www.y3web.it |
//| DEFAULT: DA TESTARE                                              |
//+------------------------------------------------------------------+

// DAX30 - dalle 8:00 alle 17:00 possibilmente su M10 (usando period converter se possibile) - i test li far� su M15.
// ingresso sulle barre Haiken Ashi di inversione vicine ai massimi/minimi giornalieri. Anche dopo aver fatto nuovi massimi/minimi giornalieri
// non si entra su HA (Haiken Ashi) doji. Miima distanza tra apertura e chiusura: 2 pips su DAX30.
// la tecnica � valida anche su ITA40, SP500, Eurostoxx
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
extern string info_p = "Se usePercentageRisk = true: POWER � la % equity da rishiare ad ogni trade. Altrimenti POWER = Lotti per ordine.";
extern int startingHour = 6; //orario di apertura da cui iniziare a verificare  massimi e minimi ed orario di inizio validit� tecnica normalmente � una o due ore pi� indietro del nostro.
extern int endingHour = 17; //orario di fine attivit� per questo strumento. Probabilmente sar� da tarare.

extern double TP_Multiplier = 1; // imposta il rapporto rischio/rendimento. da 1:1 in su su TUTTI gli ordini
extern double TP_Paolone_Multiplier = 3; // moltiplicatore degli ordini dalla parte giusta della media di bollinger
extern int numberOfOrders = 1; //usato per decidere quanti ordini aprire per ogni posizione. Moltiplica anche la distanza del TP (x1, x2, x3 etc)
extern int SL_added_pips = 2; // distanza in pip da aggiungere allo SL. Lo SL � uguale al massimo(minimo) della barra precedente + questo numero di pips. Cos� � gestibile per ogni strumento.

extern string nameOfHistoryFile = "HA_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 5;
extern bool enablePowerLIB = true;
extern bool enableAdaptive_ma = true;
extern bool enableClassicSL = true;
extern bool enableClassicTP = true;
extern bool enableAutoProfitMultiplier = true;

bool enableAdaptive_AMA = false; //presente per compatibilit� con la libreria Y3_POWER_LIB
string bot_name = "HA System";


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
double nearestMax, nearestMin; //minimo e massimo delle ultime 3 barre, per sapere se il reverse � tradabile
double min, max; //minimo e massimo di giornata, aggiornati ad ogni nuova barra


bool buyConditions[20]; 
bool sellConditions[20]; 

double atr, ARC, maxSAR, minSAR;   




//+--------------- Include ------------------------+

#include  "Y3_POWER_LIB.mqh"
//#include  "Y3_POWER_LIB_v.2.mqh"

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
   int PL = initY3_POWER_LIB(nameOfHistoryFile,SIGNATURE,Y3_POWER_LIB_maPeriod,enablePowerLIB, enableAdaptive_ma);
   
   
   //Creo i rettangoli usato per la visualizzazione dei massimi e quello per i minimi
   if (ObjectCreate(NULL,"maxRangeBox",OBJ_RECTANGLE,0,0,0,0,0) == false) 
      Alert("Errore nella creazione di maxRangeBox: "+GetLastError());
   else
      ObjectSet("maxRangeBox",OBJPROP_COLOR,DodgerBlue);
      

   if (ObjectCreate(NULL,"minRangeBox",OBJ_RECTANGLE,0,0,0,0,0) == false) 
      Alert("Errore nella creazione di minRangeBox: "+GetLastError());
   else
      ObjectSet("minRangeBox",OBJPROP_COLOR,Maroon);
   

   // ==========================
   //        bot image
   // ==========================
   long current_chart_id = ChartID();
   string bot_image_path = "\\Images\\Y3_HA_System.bmp";    // path: terminal_folder\MQL5\Images\euro.bmp
   //--- creating label bitmap (it does not have time/price coordinates)
   if(!ObjectCreate(0,"bot_image_label",OBJ_BITMAP_LABEL,0,0,0))
     {
      Alert("Error: can't create Bot Image label! code #",GetLastError());
      return(0);
     }
   else
     {
         //--- base corner
         ObjectSetInteger(0,"bot_image_label",OBJPROP_CORNER,CORNER_LEFT_UPPER);
         //--- set object properties
         ObjectSetInteger(0,"bot_image_label",OBJPROP_XDISTANCE,0);
         ObjectSetInteger(0,"bot_image_label",OBJPROP_YDISTANCE,15);
         //--- reset last error code
         ResetLastError();
         //--- load the bot image
         if(!ObjectSetString(0,"bot_image_label",OBJPROP_BMPFILE,0,bot_image_path))
           {
            PrintFormat("Error loading image from file %s. Error code %d",bot_image_path,GetLastError());
           }

         //ChartRedraw(0);

     }
   
   
   // ==========================
   //    Info Box Background
   // ==========================
   if(!ObjectCreate(0,"bot_info_box",OBJ_RECTANGLE_LABEL,0,0,0))
     {
      Alert("Error: can't create Bot Info Box! code #",GetLastError());
      return(0);
     }   
   else
     {
         //--- base corner
         ObjectSetInteger(0,"bot_info_box",OBJPROP_CORNER,CORNER_LEFT_UPPER);
         //--- set object properties
         ObjectSetInteger(0,"bot_info_box",OBJPROP_XDISTANCE,0);
         ObjectSetInteger(0,"bot_info_box",OBJPROP_YDISTANCE,70);
         //--- set box width and height
         ObjectSetInteger(0,"bot_info_box",OBJPROP_XSIZE,157);
         ObjectSetInteger(0,"bot_info_box",OBJPROP_YSIZE,170);
         //--- set box and borders colors an type
         ObjectSetInteger(0,"bot_info_box",OBJPROP_BGCOLOR,0x3f3f3f);
         ObjectSetInteger(0,"bot_info_box",OBJPROP_BORDER_COLOR,0x807e7e);
         ObjectSetInteger(0,"bot_info_box",OBJPROP_BORDER_TYPE,BORDER_FLAT);

         ChartRedraw(0);

     }


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
   ObjectDelete(ChartID(),"maxRangeBox");
   ObjectDelete(ChartID(),"minRangeBox");

   //ObjectDelete(ChartID(),"bot_image_label");


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




   // la distanza accettabile dai massimi e minimi del giorno per entrare la ricavo dall'ATR 14.
   // le posizioni long potranno aver raggiunto un prezzo superiore al minimo di giornata pari alla grandezza di tollerance.
   tollerance = iATR(nomIndice,0,100,0)/3*2;
   
   
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
      // High pu� essere inferiore a low, nel qual caso � il low e la barra � rossa.
      // Quando invece High � > Low la barra � bianca.
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
   if (haClose[1] > haOpen[1])                                 buyConditions[1] = true; //la barra HA precedente � BULL
   if (MathAbs(haClose[1]-haOpen[1]) > 1*Point)                buyConditions[2] = true; //la barra precedente ha + di 1 punto tra apertura e chiusura
   if ((haClose[2] < haOpen[2]) && (haClose[3] < haOpen[3]))   buyConditions[3] = true; //le due barre precedenti a quella sono entrambe BEAR
   if (nearestMin < min+tollerance)                            buyConditions[4] = true; //il minimo delle ultime 3 barre era vicino al minimo assoluto della giornata
   if (MarketInfo(nomIndice,MODE_BID) >= min)                  buyConditions[5] = true; // se il prezzo sta scendendo non devo rientrare (mi ha gi� buttato fuori quando ho toccato min)
   if (MarketInfo(nomIndice,MODE_BID) < upperband)             buyConditions[6] = true; // non devo essere oltre la banda superiore
   if (!existOpendedAndClosedOnThisBar(2))                     buyConditions[7] = true; // Se non ho 2 ordini aperti e chiusi in questa barra
   if (Low[0] > min)                                           buyConditions[8] = true; // solo se la barra attuale non � anche il minimo di giornata 
   if (!existOrderOnThisBar(0))                                buyConditions[9] = true; // se NON ho un ordine gi� aperto in questa barra (apre un solo ordine per ogni direzione)
   if (existOrder(0) < 0)                                      buyConditions[10] = true; // non ho gi� un ordine aperto in questa direzione (apre un solo ordine per direzione)
   
   
   if(   //(Volume[0] == 1) &&
       (buyConditions[0]) 
      && (buyConditions[1]) 
      && (buyConditions[2]) 
      && (buyConditions[3])
      && (buyConditions[4])
      && (buyConditions[5]) 
      && (buyConditions[6]) 
      && (buyConditions[7]) 
      && (buyConditions[8]) 
      && (buyConditions[9]) 
      //&& (buyConditions[10]) 
      //&& (MathAbs(haOpen[1]-haClose[1]) > MathAbs(haHigh[1]-haLow[1])/2 ) //il corpo deve essere maggiore alla met� dell'ombra
   )
   {
         entreeBuy = true; 
         //Print("BUY - b:",b," - a:",a);
   }

   
//-----------------end---------------------------------------------+




//-----------------exit buy orders---------------------------+
// dato che posso avere pi� ordini da gestire, li scorro uno per uno e valuto se vanno chiusi.
// quando ne trovo uno da chiudere setto la variabile sortieBuy = ticket.
// TIP: per usare SL e TP fissi, basta fissarli a 100 Points in pi� di quello che dovrebbero essere e poi chiuderli qui quando li raggiungono con 100 Points di differenza.
// ES. SL = 1.700, lo imposto a 1.800 nell'ordine (1.700 + 100*Point). Qui verifico se ha raggiunto prezzo SL (1.800 - 100*Point) = 1.700 e nel caso lo chiudo.
// Idem per il TP
// la procedura fermetureBuy(ticket) chiuder� l'ordine azzerando poi la variabile sortieBuy = 0
// se non ce la fa devo ripassare lo stesso ticket a fermetureBuy, finch� ce la fa.

//scorrere gli ordini per vedere se uno va chiuso
for(int pos=0;pos<OrdersTotal();pos++)
    {
     if( (OrderSelect(pos,SELECT_BY_POS)==false)
     || (OrderSymbol() != nomIndice)
     || (OrderMagicNumber() != SIGNATURE)
     || (OrderType() != 0)) continue;
     
     // Print("Trovato Ordine Buy da controllare : ",OrderTicket());
     
     //clausole di chiusura
     if ((isCameBack(OrderTicket()))                                          // se ha raggiunto il primo target e torna indietro
       || (slReached(OrderTicket()))                                           // Raggiunto SL
       || (tpReached(OrderTicket()))                                           // Raggiunto TP
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
   if (haClose[1] < haOpen[1])                                 sellConditions[1] = true; //la barra HA precedente � BEAR
   if (MathAbs(haClose[1]-haOpen[1]) > 1*Point)                sellConditions[2] = true; //la barra precedente ha + di 1 punto tra apertura e chiusura
   if ((haClose[2] > haOpen[2]) && (haClose[3] > haOpen[3]))   sellConditions[3] = true; //le due barre precedenti a quella sono entrambe BULL
   if (nearestMax > max-tollerance)                            sellConditions[4] = true; //il massimo delle ultime 5 barre era vicino al massimo assoluto della giornata
   if (MarketInfo(nomIndice,MODE_BID) <= max)                  sellConditions[5] = true; // se il prezzo sta salendo non devo rientrare (mi ha gi� buttato fuori quando ho toccato max)
   if (MarketInfo(nomIndice,MODE_BID) > lowerBand)             sellConditions[6] = true; // non devo essere oltre la banda inferiore
   if (!existOpendedAndClosedOnThisBar(2))                     sellConditions[7] = true; // Se non ho 2 ordini aperti e chiusi in questa barra
   if (High[0] < max)                                          sellConditions[8] = true; // solo se la barra attuale non � anche il massimo di giornata 
   if (!existOrderOnThisBar(1))                                sellConditions[9] = true; // se NON ho un ordine gi� aperto in questa barra (apre pi� ordini in ogni direzione)
   if (existOrder(1) < 0 )                                     sellConditions[10] = true;// non ho gi� un ordine attivo in questa direzione (apre un solo ordine per direzione)

   if(    //(Volume[0] == 1) &&
      (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2])
      && (sellConditions[3])
      && (sellConditions[4])
      && (sellConditions[5]) 
      && (sellConditions[6]) 
      && (sellConditions[7]) 
      && (sellConditions[8]) 
      && (sellConditions[9]) 
      //&& (sellConditions[10]) 
      //&& (MathAbs(haOpen[1]-haClose[1]) > MathAbs(haHigh[1]-haLow[1])/2 ) //il corpo deve essere maggiore alla met� dell'ombra
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
     if ( (isCameBack(OrderTicket()))                                           // se ha raggiunto il primo target e torna indietro
       || (slReached(OrderTicket()))                                            // Raggiunto SL
       || (tpReached(OrderTicket()))                                            // Raggiunto TP
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
  

   
   // per aprire pi� ordini uso la variabile numberOfOrders
   for (int orx=1;orx<=numberOfOrders;orx++)
   {
      if(entreeBuy == true)

      {  
         
         stoploss   = (min - (SL_added_pips*Point));
   
         //TP variabile in base alla posizione rispetto alla media di bollinger
         double middleBand = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,0);

         if ( MarketInfo(nomIndice,MODE_BID) > middleBand ) 
            {takeprofit = MarketInfo(nomIndice,MODE_ASK) + autoTargetMultiplier(TP_Paolone_Multiplier)*(MarketInfo(nomIndice,MODE_ASK) - stoploss) * orx * TP_Multiplier ;}
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
                  bool mailResult = SendMail("HA System ha aperto "+ orx +" posizioni BUY", "Strumento:"+ nomIndice +" -  "+ setPower(size));
                  if (mailResult == false) Print("Errore durante invio email BUY: "+ GetLastError());
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

  
   // per aprire pi� ordini uso la variabile numberOfOrders
   for (int orx=1;orx<=numberOfOrders;orx++)
   {
      if(entreeSell == true)
   
      {
         
         stoploss   = (max + (SL_added_pips*Point));
         
         
         //TP variabile in base alla posizione rispetto alla media di bollinger
         double middleBand = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,0);



         if ( MarketInfo(nomIndice,MODE_BID) < middleBand ) 
            {takeprofit = MarketInfo(nomIndice,MODE_BID) - autoTargetMultiplier(TP_Paolone_Multiplier)*(stoploss - MarketInfo(nomIndice,MODE_BID)) * orx * TP_Multiplier;}
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
                  bool mailResult = SendMail("HA System ha aperto "+ orx +" posizioni SELL", "Strumento:"+ nomIndice +" -  "+ setPower(size));
                  if (mailResult == false) Print("Errore durante invio email SELL: "+ GetLastError());
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


//------- VERIFICA ESISTENZA ORDINI APERTI IN QUESTA BARRA ED ANCORA ATTIVI ----------+

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



//------- VERIFICA ESISTENZA ORDINI APERTI E CHIUSI IN QUESTA BARRA ----------+

bool existOpendedAndClosedOnThisBar(int maxOrders) 
   {
      bool result = false;
      
      int total = OrdersTotal();
      int o = 0;
      
      for (int i=OrdersHistoryTotal()-1; i>=0; i--)
      {
         

         if ( (OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true) && (OrderMagicNumber()==SIGNATURE) && (OrderSymbol()==nomIndice) && (iBarShift(nomIndice,0,OrderOpenTime(),false) == 0) && (iBarShift(nomIndice,0,OrderCloseTime(),false) == 0))         
         {
            o = o+1; // ho un ordine aperto e chiuso in questa barra
            
            if (o >= maxOrders) 
               {
                  result = true; // se ho N ordini aperti e chiusi in questa barra, esco e restituisco true 
                  //Print("existOpendedAndClosedOnThisBar ("+ o +") : "+ OrderTicket());
                  break;                  
               }
         }

      }
      
      return result;    
      
   }
//-----------------end----------------------------------------+ 




// Modifica distanza Take Profit in base agli ordini passati ---------------------------- +
double autoTargetMultiplier(double maxMultiplier){

   //se la funzione � disattivata, esco prima di iniziare resituendo il moltiplicatore indicato 
   if (enableAutoProfitMultiplier == false)    return maxMultiplier;
   
   
   // Restituisce un moltiplicatore da usare nell'apertura ordine per calcolare il TP
   // la moltiplicazione in questo sistema parte dal rischio.
   // il moltiplicatore non pu� mai essere inferiore ad 1 (R.R = 1:1 minimo)
   // dato il maxMultiplier, sottraggo 1 e divido per 10, perch� analizzo 10 ordini storici
   // per ogni ordine in perdita sottraggo un decimo dal maxMultiplier
   // con 0 ordini in perdita, restituisco maxMultiplier
   // con 10 ordini in perdita restituisco 1
   
   int i = 0;
   int o = 0;
   
   double step = 0; // un decimo della distanza tra 1 e maxMultiplier
   step = (maxMultiplier - 1)/10;
   step = NormalizeDouble(step,2);

   o = 0; //azzero il contatore
    
   //loop history and get orders of this robot
   for (i=OrdersHistoryTotal()-1; i>=0; i--) 
   {
      if ( (OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true) && (OrderMagicNumber()==SIGNATURE) && (OrderSymbol()==nomIndice) )
      {
         o = o+1;
         if (OrderProfit() < 0) maxMultiplier = maxMultiplier - step;
         //Scrivo la data dell'ordine
         //Print("autoTargetMultiplier: Order "+OrderTicket() +" Profit "+ OrderProfit() +" - Multiplier: "+maxMultiplier);
         
         if (o == 10) break;
         
      }
      
      if (o == 10) break;
      
   }
   
   // mai minore di 1 (ORIGINALE)
   if (maxMultiplier < 1) maxMultiplier = 1;
   
   // 27/07/2015 - credo di aver trovato un bug
   // il maxMultiplier dovrebbe essere 1+il numero trovato! Invece era pari al numero trovato!
   // maxMultiplier = 1 + maxMultiplier;
   
   
   //Print("autoTargetMultiplier: ",maxMultiplier );
   return maxMultiplier;

}







// verifica se un ordine raggiunge o supera lo stop loss
bool slReached(int tkt)
{

   //se la funzione � disattivata, esco prima di iniziare
   if (enableClassicSL == false) return false;
   
   double hiddener = 0;
   bool result = false;
   hiddener = 1000*Point; // gli SL sono mascheratti
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
     
      if ((OrderType() == OP_BUY) ) // buy order
      {
         if (MarketInfo(nomIndice,MODE_BID) <= OrderStopLoss() + hiddener)
         {result = true; Print("slReached: BUY order ", tkt, " - CHIUDERE");}
      }

 
      if ((OrderType() == OP_SELL) ) // sell order
      {
         
         //if (MarketInfo(nomIndice,MODE_ASK) >= OrderStopLoss() - hiddener) //versione originale
         if (MarketInfo(nomIndice,MODE_BID) >= OrderStopLoss() - hiddener) //versione originale
         {result = true; Print("slReached: SELL order ", tkt, " - CHIUDERE");}
      }
       
   }
      return result;

}
//-----------------end----------------------------------------+ 



// verifica se un ordine raggiunge o supera il Take Profit
bool tpReached(int tkt)
{

   //se la funzione � disattivata, esco prima di iniziare
   if (enableClassicTP == false) return false;

   double hiddener = 0;
   bool result = false;
   hiddener = 1000*Point; // gli SL sono mascheratti
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
     
      if ((OrderType() == OP_BUY) ) // buy order
      {
         if (MarketInfo(nomIndice,MODE_BID) >= OrderTakeProfit() - hiddener)
         {result = true; Print("tpReached: BUY order ", tkt, " - CHIUDERE");}
      }

 
      if ((OrderType() == OP_SELL) ) // sell order
      {
         if (MarketInfo(nomIndice,MODE_ASK) <= OrderTakeProfit() + hiddener)
         {result = true; Print("tpReached: SELL order ", tkt, " - CHIUDERE");}
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
      profit = MathAbs(OrderOpenPrice() - OrderStopLoss()) - hiddener;  // tutti gli ordini di un gruppo hanno lo stesso rischio, che � uguale al primo TP
      
     
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







//--------------- SIZE AUTOMATICA ----------------------------+ 
double getSize(int risk, double distance)
{
   double equity = AccountEquity();
   double amountRisked = equity/100*risk;
   double finalSize = 0;
   double tickValue = MarketInfo(nomIndice,MODE_TICKVALUE); //valore di un tick con un lotto 
   double minLot = MarketInfo(nomIndice,MODE_MINLOT);
   
   distance = distance/Point; //la distanza deve sempre essere un intero
   
   amountRisked = MathRound(amountRisked/numberOfOrders);
   finalSize = amountRisked/distance;
   
   finalSize = amountRisked/(tickValue*distance);
   
   // arrotondo i lotti in base a quello che pu� accettare questo strumento
   if (minLot == 1) finalSize = NormalizeDouble(finalSize,0);
   if (minLot == 0.1) finalSize = NormalizeDouble(finalSize,1);
   if (minLot == 0.01) finalSize = NormalizeDouble(finalSize,2);
   
   
   Print("getSize() - Risk="+risk+" - Distamce="+distance+" - amountRisked="+amountRisked+" - finalSize="+finalSize);
   if (usePercentageRisk == true) 
      return finalSize;
   else
      return POWER;
}

//-----------------end----------------------------------------+ 







//-------------------prints------------------------------+

int commentaire()

   {

   

    Comment( "\n ","\n ","\n ","\n ",
            "\n ",bot_name, ": ",nomIndice,

            "\n ",
            
            "\n Base POWER: ",POWER,
            
            "\n SL Added Pips: ",SL_added_pips,
            
            "\n Base TPMultip.: ",TP_Paolone_Multiplier,
            
            "\n ",
            
            "\n TRADES: ",ArraySize(historicPips),
            
            "\n ",
            
            "\n Pips / LIB: ",historicPips[ArraySize(historicPips)-1], " / ", historicPipsMA[ArraySize(historicPipsMA)-1],
            
            "\n Next Order TPMultip.: ",autoTargetMultiplier(TP_Paolone_Multiplier),
            
            "\n Periods Base / Adaptive: ",Y3_POWER_LIB_maPeriod ," / ", adaptive_maPeriod,
            
            "\n Next Order Size: ",setPower(POWER),

            "\n Tick Value: ",MarketInfo(nomIndice,MODE_TICKVALUE),

            
//            "\n +-----------------------------   ",
//            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],
//            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],
//            "\n +-----------------------------   ",


            "");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+