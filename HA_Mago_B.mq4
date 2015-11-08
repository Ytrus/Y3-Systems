//+------------------------------------------------------------------+
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
 
//--------------------------+
// BOT NAME AND VERSION
//--------------------------+
string bot_name = "Mago 0.3.312 "; // Inserito filtro [10] per impedire acquisti fuori dalle Bande di Bollinger
string botSettings; //contiene i settaggi del Bot


//--------Index name------+
string nomIndice = "GER30"; //sovrascritto dopo in init()
                          
//--------number of lots to trade--------------+
extern string ext_bot_settings = "=============== Bot Settings ===============";
extern int SIGNATURE = 0018000;
extern string COMMENT = "HA";
extern string nameOfHistoryFile = "HA_System_HST_";

extern string ext_trade_settings = "=============== Trade Settings ===============";
extern double POWER = 0.1;                                                              
extern string startingHour = "00:00";           /*startingHour: orario inizio attività*/        
extern string endingHour = "23:59";             /*endingHour: orario di fine attività*/         
extern int SL_added_pips = 2;                   /*SL_added_pips: pip da aggiungere allo SL*/    
extern int LooseRecoveryRatio = 100;            /*Loose RecoveryRatio (%)*/                     
extern int WinRecoveryRatio = -50;              /*Win RecoveryRatio (%)*/                       
extern double RecoveryStopper = 1;            /*Recover Stopper (0.0 - 1.0)*/                 
extern int nFast = 2;                           /*AMA nFast*/
extern int min_SL_Distance = 0;                 /*min. Stop Loss Distance*/
extern int max_SL_Distance = 10000;             /*max. Stop Loss Distance*/
extern int protectionStartDistance = 90;        /*Cameback % Start*/
extern int protectionCloseDistance = 80;           /*Cameback % Protection*/
extern int SuperTrend = 14;
extern string openHours = "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23";                            

extern string ext_web_server_settings = "=============== Web Server ===============";
extern bool registerBars = true; //registerBars: registra le barre sul web server
extern bool registerOrders = true; //registerOrders: registra gli ordini sul web server

extern string ext_email_settings = "=============== email Settings ===============";
extern bool sendEmailOnOrderOpen = false; //Manda una mail quando apre un ordine
extern bool sendEmailOnOrderClose = false; //Manda una mail quando chiude un ordine

extern string ext_test_settings = "=============== test Settings ===============";
extern bool usePercentageRisk = false;                                                 
extern string Notes = "";                                                     



int Y3_POWER_LIB_maPeriod = 5;
double TP_Multiplier = 1;              // imposta il rapporto rischio/rendimento. da 1:1 in su su TUTTI gli ordini
double TP_Paolone_Multiplier = 3;      // moltiplicatore degli ordini dalla parte giusta della media di bollinger
int numberOfOrders = 1;                //usato per decidere quanti ordini aprire per ogni posizione. Moltiplica anche la distanza del TP (x1, x2, x3 etc)

bool enablePowerLIB = true;
bool enableAdaptive_ma = true;
bool enableClassicSL = true;
bool enableClassicTP = true;
bool enableAutoProfitMultiplier = true;

bool enableAdaptive_AMA = false;       //presente SOLO per compatibilità con la libreria Y3_POWER_LIB


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

double tollerance; // tolleranza in pip della distanza dai massimi e minimi per entrare sui reverse

double haOpen[10], haClose[10], haHigh[10], haLow[10]; // arrays con i valori delle Haiken Ashi
double haOpenM15[10], haCloseM15[10], haHighM15[10], haLowM15[10]; // arrays con i valori delle Haiken Ashi sul grafico a 15M
double midBand[10], lowerBand[10], upperband[10]; // valori di bollinger nelle ultime 10 barre
double nearestMax, nearestMin; //minimo e massimo delle ultime 3 barre, per sapere se il reverse è tradabile
double min, max; //minimo e massimo di giornata, aggiornati ad ogni nuova barra
double tpPaolone = 1; //usato nell'inserimento ordini, necessario per avere il valore dopo l'inserimento dell'ordine

bool enabledHours[24]; // array con le singole ore in cui c'è indicato se tradare o no (true o false)


bool buyConditions[20]; 
bool sellConditions[20]; 
string closeDescription; // per sapere perchè ha chiuso un ordine e scriverlo sul web Server

double atr, ARC, maxSAR, minSAR;   


datetime lastAnalizedBarTime;       // per eseguire alcuni controlli una sola volta per barra: inizializzato in init
datetime blockedBy_getSLDistance_for_BUY;   // getSLDistance salva qui il Time[] dell'ultima barra bloccata da lui
datetime blockedBy_getSLDistance_for_SELL;   // getSLDistance salva qui il Time[] dell'ultima barra bloccata da lui
bool webBarDataSendedToServer;      // gestisce se inviare o no i dati iniziali di una barra al webServer
int simulationID;                   // serve per scrivere un ID univoco nella simulazione sul web server per distinguerle
int actualPeriod; //periodo del grafico attuale
int slowerPeriod;   // periodo del timeframe superiore a cui calcolare il supertrend
//+--------------- Include ------------------------+

//#include  "Y3_POWER_LIB.mqh"
#include  "Y3_POWER_LIB_Recovery.mqh"
//#include  "Y3_POWER_LIB_Recovery_Swap.mqh"
#include    "WebRequest.mqh"

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
      Alert("Errore nella creazione di maxRangeBox: "+(string)GetLastError());
   else
      ObjectSet("maxRangeBox",OBJPROP_COLOR,DodgerBlue);
      

   if (ObjectCreate(NULL,"minRangeBox",OBJ_RECTANGLE,0,0,0,0,0) == false) 
      Alert("Errore nella creazione di minRangeBox: "+(string)GetLastError());
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

   // inizializzo lastAnalizedBarTime facendo finta che l'ultima barra analizzata sia la penultima
   lastAnalizedBarTime = Time[1];

   // fingo che l'ultima barra bloccata sia la penultima, in modo da analizzare correttamente la prima barra di partenza
   blockedBy_getSLDistance_for_BUY = Time[1];
   blockedBy_getSLDistance_for_SELL = Time[1];
   
   // per registrare i dati iniziali di questa barra
   webBarDataSendedToServer = false; 


   //-------------------------------------------------+
   // Disabilito le funzionalità assenti in testing   |
   //-------------------------------------------------+
   if (IsTesting())
   {
         registerBars = false;               // non tentare di registrare le barre sul web Server
         sendEmailOnOrderOpen = false;       // non tentare di inviare email all'apertura di un ordine
         sendEmailOnOrderClose = false;      // non tentare di invare email alla chiusura di un ordine
         simulationID = GetTickCount();      // generato SOLO in simulazione. Se <> null il web server registra l'ordine nella tabella SimulationsOrder, altrimenti in Orders (reali)
   }

   //-------------------------------------------------------------------+
   //      SETTAGGI DEL BOT PER LA REGISTRAZIONE SU WEBSERVER           |
   //-------------------------------------------------------------------+
   botSettings = "Lotti:+"+(string)POWER+",+";
   botSettings += "startingHour:+"+(string)startingHour+",+";
   botSettings += "endingHour:+"+(string)endingHour+",+";
   botSettings += "SL_added_pips:+"+(string)SL_added_pips+",+";     
   botSettings += "LooseRecoveryRatio:+"+(string)LooseRecoveryRatio+",+";
   botSettings += "WinRecoveryRatio:+"+(string)WinRecoveryRatio+",+";
   botSettings += "RecoveryStopper:+"+(string)RecoveryStopper+",+";
   botSettings += "nFast:+"+(string)nFast+",+";
   botSettings += "min_SL_Distance:+"+(string)min_SL_Distance+",+";
   botSettings += "max_SL_Distance:+"+(string)max_SL_Distance+",+";
   botSettings += "openHours:+"+openHours+",+";
   botSettings += "usePercentageRisk:+"+(string)usePercentageRisk+",+";
   botSettings += "protectionStartDistance:+"+(string)protectionStartDistance+",+";
   botSettings += "protectionCloseDistance:+"+(string)protectionCloseDistance+",+";
   botSettings += "SuperTrend:+"+(string)SuperTrend+",+";
   botSettings += "Spread:+"+(string)MarketInfo(nomIndice, MODE_SPREAD)+""; // ATTENZIONE !! ricordarsi che l'ultimo è senza virgola finale!!
   

   
   
   //-------------------------------------------------------------------+
   //                 IMPOSTO LE ORE DI TRADING                         |
   //-------------------------------------------------------------------+
   
   // creo un array temporaneo con le ore indicate dall'utente
   string taResult[];
   ushort sep=StringGetCharacter(",",0);
   StringSplit(openHours,sep,taResult);

   // in ogni ora metto true se ho quell'ora nell'array taResult
   for (int i=0; i<ArraySize(enabledHours); i++){
      enabledHours[i] = false;
      for (int b=0; b<ArraySize(taResult); b++){
         if ((int)taResult[b] == i) enabledHours[i] = true;
      }
      
   }
   Print(enabledHours[0]+","+enabledHours[1]+","+enabledHours[2]+","+enabledHours[3]+","+enabledHours[4]+","+enabledHours[5]+","+enabledHours[6]+","+enabledHours[7]+","+enabledHours[8]+","+enabledHours[9]+","+enabledHours[10]+","+enabledHours[11]+","+enabledHours[12]+","+enabledHours[13]+","+enabledHours[14]+","+enabledHours[15]+","+enabledHours[16]+","+enabledHours[17]+","+enabledHours[18]+","+enabledHours[19]+","+enabledHours[20]+","+enabledHours[21]+","+enabledHours[22]+","+enabledHours[23]);



   // scelta dei periodi superiori per SUPERTREND
   switch(Period())
     {
      case 1:     slowerPeriod=30; break;
      case 5:     slowerPeriod=60; break;
      case 15:    slowerPeriod=240; break;
      case 30:    slowerPeriod=1440; break;
      case 60:    slowerPeriod=1440; break;
      case 240:   slowerPeriod=10080; break;
      case 1440:  slowerPeriod=10080; break;
      case 10080: slowerPeriod=43200; break;
      case 43200: slowerPeriod=15; Print("Impossibile usare questo EA sul timeframe mensile"); deinit();
     }
     
     Print("Trend Period Filter: "+slowerPeriod);
     
   // test x l'invio di un ordine al webserver (cambiare il ticket perchè dopo un mese escono dalla history!)
   // bool test = webSendOpenOrder(18371722,3);
   // bool  test = webSendCloseOrder(18371722,3);

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

   //Elimino i l'immagine ed il background box
   ObjectDelete(ChartID(),"bot_image_label");
   ObjectDelete(ChartID(),"bot_info_box");


   // cambio lastAnalizedBarTime per essere sicuro che se rilanciato non consideri questa barra già analizzata
   lastAnalizedBarTime = Time[1];

   // fingo che l'ultima barra bloccata sia la penultima, in modo da analizzare correttamente la prima barra di partenza
   blockedBy_getSLDistance_for_BUY = Time[1];
   blockedBy_getSLDistance_for_SELL = Time[1];

   // per registrare i dati iniziali di questa barra
   webBarDataSendedToServer = false; 

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

   ouvertureSell();

   commentaire();

//----

   return(0);

  }

//+---------------------end-----------------------------+

 

//------------------------Subroutine parameters--------------------------+

int paramD1()

{ 

   int startBarOffset, highestBarShift, lowestBarShift;   

   entreeBuy  = false;
   
   entreeSell = false;
     
   ArrayInitialize(buyConditions,false);   //Array buyConditions per debuggare
   ArrayInitialize(sellConditions,false);  //Array sellConditions per debuggare

   // ===============================================================================
   // determino le date e gli orari delle barre di start e di end del trading system   
   // ===============================================================================
   tm = TimeCurrent();
   
   /* === nuovo sistema di determinazione orari di trading ===== */
   startTime = StrToTime(startingHour);
   endTime = StrToTime(endingHour);
   
   startBarOffset = 4; //iBarShift(nomIndice,0,startTime,false) + 1; //offset della barra di inizio giornata
   
   
   // DEBUG verifico di avere individuato la barra giusta
   //if (ObjectCreate(NULL,"StartTradingBarArrow",OBJ_ARROW_DOWN,0,startTime,High[startBarOffset]+20*Point) == false)
   //   Alert("Errore nella creazione dell'arrow. "+GetLastError());
   //if (Volume[0] == 1) Alert("Barra di inzio giornata: H "+High[startBarOffset]+" - O "+Open[startBarOffset]+" - C "+Close[startBarOffset]+" - L"+Low[startBarOffset]);




   // la distanza accettabile dai massimi e minimi del giorno per entrare la ricavo dall'ATR 14.
   // le posizioni long potranno aver raggiunto un prezzo superiore al minimo di giornata pari alla grandezza di tollerance.
   tollerance = iATR(nomIndice,0,100,0)/3*2;
   tollerance = NormalizeDouble(tollerance,Digits);
   
   
   if (iBarShift(nomIndice,0,lastAnalizedBarTime,false) > 0 ) //(Volume[0] == 1)
   {
      
      // Determino massimi e minimi delle ultime n barre
      highestBarShift = iHighest(nomIndice,0,MODE_HIGH,startBarOffset,1);
      lowestBarShift  = iLowest(nomIndice,0,MODE_LOW,startBarOffset,1);
      
      //Recupero i valori di prezzo del massimo e del minimo di giornata
      max = High[highestBarShift];
      min = Low[lowestBarShift];
      
      // minimo e massimo visti nelle ultime 5 barre (per sapere se poter entrare sul reverse)
      nearestMax = High[iHighest(nomIndice,0,MODE_HIGH,5,0)];
      nearestMin = Low[iLowest(nomIndice,0,MODE_LOW,5,0)];

      //aggiorno lastAnalizedBarTime in modo che fino alla prossima barra tutto questo non venga eseguito
      lastAnalizedBarTime = Time[0];

      // dico al bot che deve ancora spedire i dati iniziali di questa barra al webServer
      webBarDataSendedToServer = false; 
      
   }
   

// ------------------ Attribuzione Haiken Ashi --------------------

   for (int i=0;i<10;i++)
   {  // High e Low delle Heiken Ashi non funzionano come i prezzi
      // High può essere inferiore a low, nel qual caso è il low e la barra è rossa.
      // Quando invece High è > Low la barra è bianca.
      /*
      haOpen[i]  = iCustom(nomIndice,0,"Heiken Ashi",HA_OPEN,i);
      haClose[i] = iCustom(nomIndice,0,"Heiken Ashi",HA_CLOSE,i);
      haHigh[i]  = MathMax(iCustom(nomIndice,0,"Heiken Ashi",HA_HIGH,i),iCustom(nomIndice,0,"Heiken Ashi",HA_LOW,i));
      haLow[i]   = MathMin(iCustom(nomIndice,0,"Heiken Ashi",HA_HIGH,i),iCustom(nomIndice,0,"Heiken Ashi",HA_LOW,i));
      */
      // HA a 15 minuti
      /*
      haOpenM15[i]  = iCustom(nomIndice,PERIOD_M5,"Heiken Ashi",HA_OPEN,i);
      haCloseM15[i] = iCustom(nomIndice,PERIOD_M5,"Heiken Ashi",HA_CLOSE,i);
      haHighM15[i]  = MathMax(iCustom(nomIndice,PERIOD_M5,"Heiken Ashi",HA_HIGH,i),iCustom(nomIndice,0,"Heiken Ashi",HA_LOW,i));
      haLowM15[i]   = MathMin(iCustom(nomIndice,PERIOD_M5,"Heiken Ashi",HA_HIGH,i),iCustom(nomIndice,0,"Heiken Ashi",HA_LOW,i));
      */

      lowerBand[i] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_LOWER,i);
      upperband[i] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_UPPER,i);
      midBand[i] = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,i);
      
   }
    //PROVA CON FILTRO Supertrend 14 
    double trendUp, trendDown;
    trendUp = iCustom(nomIndice,slowerPeriod,"downloads\\SuperTrend",SuperTrend,false,14,14,14,14,14,14,14,14,14,0,0);
    trendDown = iCustom(nomIndice,slowerPeriod,"downloads\\SuperTrend",SuperTrend,false,14,14,14,14,14,14,14,14,14,1,0);
    
    
//-----------------enter buy order---------------------------+

   // buyConditions array
   
   
   if (Low[1] < lowerBand[1])                                  buyConditions[0] = true;   // La barra precedente ha il minimo sotto alla barra inferiore di bollinger
   if (Close[0] > High[1])                                     buyConditions[1] = true;   // il prezzo sale oltre al massimo della barra precedente
   if ( (Close[0] < midBand[0]) )                              buyConditions[2] = true;   // il prezzo attuale è sotto alla middle band di Bollinger
   if (!existOrderOnThisBar(0))                                buyConditions[3] = true;   // se NON ho un ordine già aperto in questa barra (apre un solo ordine per ogni direzione)
   if (getSLDistance("BUY", min_SL_Distance, max_SL_Distance)) buyConditions[4] = true;   // lo SL è almeno distante quanto richiesto
   if (enabledHours[Hour()] == true)                           buyConditions[5] = true;   // A questa ora posso tradare
   if (isGoingUpAndDown())                                     buyConditions[6] = true;   // se almeno una delle ultime 10 barre chiudeva sopra a midBand (sto zigzagando)
   if (!existOpendedAndClosedOnThisBar(1))                     buyConditions[7] = true;   // Se non ho 1 ordine aperto e chiuso in questa barra
   //if (existOrder(0) < 0)                                    buyConditions[8] = true;   // non ho già un ordine aperto in questa direzione (apre un solo ordine per direzione)
   //if ((Close[0] < trendUp) && (trendUp != EMPTY_VALUE))     buyConditions[9] = true;  // Solo se il trend daily è UP - CON BUG
   if ((Close[0] > trendUp) && (trendUp != EMPTY_VALUE))       buyConditions[9] = true;  // Solo se il trend daily è UP - SENZA BUG
   if (Close[0] < upperband[0])                                buyConditions[10] = true;    // Non sono salito oltre la upperBand

   /*
   if ((startTime <= tm) && (tm < endTime))                    buyConditions[0] = true;
   if (haClose[1] > haOpen[1])                                 buyConditions[1] = true; //la barra HA precedente è BULL
   if (MathAbs(haClose[1]-haOpen[1]) > 1*Point)                buyConditions[2] = true; //la barra precedente ha + di 1 punto tra apertura e chiusura
   if ((haClose[2] < haOpen[2]) && (haClose[3] < haOpen[3]))   buyConditions[3] = true; //le due barre precedenti a quella sono entrambe BEAR
   if (nearestMin < min+tollerance)                            buyConditions[4] = true; //il minimo delle ultime 3 barre era vicino al minimo assoluto della giornata
   if (MarketInfo(nomIndice,MODE_BID) >= min)                  buyConditions[5] = true; // se il prezzo sta scendendo non devo rientrare (mi ha già buttato fuori quando ho toccato min)
   if (MarketInfo(nomIndice,MODE_BID) < upperband)             buyConditions[6] = true; // non devo essere oltre la banda superiore
   if (!existOpendedAndClosedOnThisBar(2))                     buyConditions[7] = true; // Se non ho 2 ordini aperti e chiusi in questa barra
   if (Low[0] > min)                                           buyConditions[8] = true; // solo se la barra attuale non è anche il minimo di giornata 
   if (!existOrderOnThisBar(0))                                buyConditions[9] = true; // se NON ho un ordine già aperto in questa barra (apre un solo ordine per ogni direzione)
   if (getSLDistance("BUY", min_SL_Distance, max_SL_Distance)) buyConditions[10] = true; // lo SL è almeno distante quanto richiesto
   if (enabledHours[Hour()] == true)                           buyConditions[11] = true; // A questa ora posso tradare
   //if (existOrder(0) < 0)                                    buyConditions[12] = true; // non ho già un ordine aperto in questa direzione (apre un solo ordine per direzione)
   */
   
   if(   (buyConditions[0]) 
      && (buyConditions[1]) 
      //&& (buyConditions[2]) 
      && (buyConditions[3])
      && (buyConditions[4])
      && (buyConditions[5]) 
      && (buyConditions[6]) 
      && (buyConditions[7]) 
      //&& (buyConditions[8]) 
      //&& (buyConditions[9])       
      && (buyConditions[10])       
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
     if ((isCameBack_One(OrderTicket(), 0))                                                        // se dopo aver visto un profitto di 1:1 torna indietro
       || (protector(OrderTicket(), protectionStartDistance, protectionCloseDistance))             // se ha raggiunto una certa percentuale di profitto e poi torna indietro
       || (slReached(OrderTicket()))                                                               // Raggiunto SL
       || (tpReached(OrderTicket()))                                                               // Raggiunto TP
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
   if (High[1] > upperband[1])                                 sellConditions[0] = true;     // La barra precedente ha il massimo sopra alla barra superiore di bollinger
   if (Close[0] < Low[1])                                      sellConditions[1] = true;     // il prezzo scende oltre al minimo della barra precedente
   if (Close[0] > midBand[0])                                  sellConditions[2] = true;     // il prezzo attuale è sopra alla middle band di Bollinger
   if (!existOrderOnThisBar(1))                                sellConditions[3] = true;     // se NON ho un ordine già aperto in questa barra (apre più ordini in ogni direzione)
   if (getSLDistance("SELL", min_SL_Distance, max_SL_Distance))sellConditions[4] = true;     // lo SL è almeno distante quanto richiesto
   if (enabledHours[Hour()] == true)                           sellConditions[5] = true;     // A questa ora posso tradare
   if (isGoingUpAndDown())                                     sellConditions[6] = true;     // se almeno una delle ultime 10 barre chiudeva sopra a midBand (sto zigzagando)
   if (!existOpendedAndClosedOnThisBar(1))                     sellConditions[7] = true;     // Se non ho 1 ordine aperto e chiuso in questa barra   
   //if (existOrder(1) < 0 )                                   sellConditions[8] = true;     // non ho già un ordine attivo in questa direzione (apre un solo ordine per direzione)
   if ((Close[0] > trendDown) && (trendDown != EMPTY_VALUE))   sellConditions[9] = true;     // Solo se il trend daily è DOWN - CON BUG
   //if ((Close[0] < trendDown) && (trendDown != EMPTY_VALUE))   sellConditions[9] = true;   // Solo se il trend daily è DOWN - SENZA BUG
   if (Close[0] > lowerBand[0])                                sellConditions[10] = true;    // Non sono sceso oltre la lowerBand


   /*
   if ((startTime <= tm) && (tm < endTime))                    sellConditions[0] = true; 
   if (haClose[1] < haOpen[1])                                 sellConditions[1] = true; //la barra HA precedente è BEAR
   if (MathAbs(haClose[1]-haOpen[1]) > 1*Point)                sellConditions[2] = true; //la barra precedente ha + di 1 punto tra apertura e chiusura
   if ((haClose[2] > haOpen[2]) && (haClose[3] > haOpen[3]))   sellConditions[3] = true; //le due barre precedenti a quella sono entrambe BULL
   if (nearestMax > max-tollerance)                            sellConditions[4] = true; //il massimo delle ultime 5 barre era vicino al massimo assoluto della giornata
   if (MarketInfo(nomIndice,MODE_BID) <= max)                  sellConditions[5] = true; // se il prezzo sta salendo non devo rientrare (mi ha già buttato fuori quando ho toccato max)
   if (MarketInfo(nomIndice,MODE_BID) > lowerBand)             sellConditions[6] = true; // non devo essere oltre la banda inferiore
   if (!existOpendedAndClosedOnThisBar(2))                     sellConditions[7] = true; // Se non ho 2 ordini aperti e chiusi in questa barra
   if (High[0] < max)                                          sellConditions[8] = true; // solo se la barra attuale non è anche il massimo di giornata 
   if (!existOrderOnThisBar(1))                                sellConditions[9] = true; // se NON ho un ordine già aperto in questa barra (apre più ordini in ogni direzione)
   if (getSLDistance("SELL", min_SL_Distance, max_SL_Distance))sellConditions[10] = true; // lo SL è almeno distante quanto richiesto
   if (enabledHours[Hour()] == true)                           sellConditions[11] = true; // A questa ora posso tradare
   //if (existOrder(1) < 0 )                                   sellConditions[12] = true;// non ho già un ordine attivo in questa direzione (apre un solo ordine per direzione)
   */
   
   if(   (sellConditions[0])  
      && (sellConditions[1]) 
      //&& (sellConditions[2])
      && (sellConditions[3])
      && (sellConditions[4])
      && (sellConditions[5]) 
      && (sellConditions[6]) 
      && (sellConditions[7]) 
      //&& (sellConditions[8])
      //&& (sellConditions[9])
      && (sellConditions[10]) 
      
   )
   {
      entreeSell = true; 
      //Print("SELL - b:",b," - a:",a);
   }
   
//-----------------end---------------------------------------------+
 
//-----------------exit sell orders---------------------------+


//scorrere gli ordini per vedere se uno va chiuso
for(int pos=0;pos<OrdersTotal();pos++)
    {
     if( (OrderSelect(pos,SELECT_BY_POS)==false)
     || (OrderSymbol() != nomIndice)
     || (OrderMagicNumber() != SIGNATURE)
     || (OrderType() != 1)) continue;
     
     //Print("Trovato Ordine Sell da controllare : ",OrderTicket());
     
     //clausole di chiusura
     if ( (isCameBack_One(OrderTicket(), 0))                                                       // se dopo aver visto un profitto di 1:1 torna indietro
       || (protector(OrderTicket(), protectionStartDistance, protectionCloseDistance))             // se ha raggiunto una certa percentuale di profitto e poi torna indietro
       || (slReached(OrderTicket()))                                                               // Raggiunto SL
       || (tpReached(OrderTicket()))                                                               // Raggiunto TP
       )
     {
      sortieSell = OrderTicket();       
     // Print("Trovato Ordine Sell da chiudere: ",OrderTicket());

      fermetureSell(OrderTicket());
     }

    }
   

//-----------------end---------------------------------------------+



   //-------------------------------------------------------+
   // scrivo sul webserver i dati iniziali di questa barra  |
   //-------------------------------------------------------+
   if ((webBarDataSendedToServer == false) && (registerBars == true))
   {
      // encoded strings
      string bot_name_encoded = bot_name; StringReplace(bot_name_encoded, " ", "+");
      
      webRequestBody = 
      "accountID="            +(string)AccountNumber()+
      "&symbol="              +(string)nomIndice+
      "&barOpenTime="         +(string)TimeYear(Time[0])+"-"+(string)TimeMonth(Time[0])+"-"+(string)TimeDay(Time[0])+"+"+(string)TimeHour(Time[0])+"%3A"+(string)TimeMinute(Time[0])+"%3A"+(string)TimeSeconds(Time[0])+
      "&barRegistrationTime=" +(string)TimeYear(TimeCurrent())+"-"+(string)TimeMonth(TimeCurrent())+"-"+(string)TimeDay(TimeCurrent())+"+"+(string)TimeHour(TimeCurrent())+"%3A"+(string)TimeMinute(TimeCurrent())+"%3A"+(string)TimeSeconds(TimeCurrent())+
      "&systemName="          +bot_name_encoded+
      "&systemMagic="         +(string)SIGNATURE+
      "&ask="                 +(string)MarketInfo(nomIndice,MODE_ASK)+
      "&bid="                 +(string)MarketInfo(nomIndice,MODE_BID)+
      
      // aggiungere le informazioni di partenza se necessario
      "&startingInfo="+
      "Buy+Conditions:+0."    +(string)buyConditions[0]+"+1."+(string)buyConditions[1]+"+2."+(string)buyConditions[2]+"+3."+(string)buyConditions[3]+"+4."+(string)buyConditions[4]+"+5."+(string)buyConditions[5]+"+6."+(string)buyConditions[6]+"+7."+(string)buyConditions[7]+"+8."+(string)buyConditions[8]+"+9."+(string)buyConditions[9]+";+"+(string)buyConditions[10]+";+"+
      "Sell+Conditions:+0."   +(string)sellConditions[0]+"+1."+(string)sellConditions[1]+"+2."+(string)sellConditions[2]+"+3."+(string)sellConditions[3]+"+4."+(string)sellConditions[4]+"+5."+(string)sellConditions[5]+"+6."+(string)sellConditions[6]+"+7."+(string)sellConditions[7]+"+8."+(string)sellConditions[8]+"+9."+(string)sellConditions[9]+";+"+(string)sellConditions[10]+";+"+
      "nearestMin:+"          +(string)nearestMin+";+"+
      "nearestMax:+"          +(string)nearestMax+";+"+
      "min:+"                 +(string)min+";+"+
      "max:+"                 +(string)max+";+"+
      "tollerance:+"          +(string)tollerance+";+"
      ;
      
      // invio la richiesta al webServer
      webBarDataSendedToServer = sendRequest("http://www.y3web.it/addNewBar.asp",webRequestBody,"Registrazione Barra",3);
      
   }


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
         
         stoploss   = (Low[1] - (SL_added_pips*Point));
   
         //TP variabile in base alla posizione rispetto alla media di bollinger
         double middleBand = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,0);
         tpPaolone = 2;

         // applico il moltiplicatore del TP solo se siamo sopra alla media
         // ================= VERSIONE ORIGINALE =============
         //if ( MarketInfo(nomIndice,MODE_BID) > middleBand ) tpPaolone = autoTargetMultiplier(TP_Paolone_Multiplier);
         
         // =============== VERSIONE AUTOADATTANTE IN ENTRAMBI I CASI ===================
         //tpPaolone = autoTargetMultiplier(TP_Paolone_Multiplier);
         


         takeprofit = MarketInfo(nomIndice,MODE_ASK) + tpPaolone*(MarketInfo(nomIndice,MODE_ASK) - stoploss) * orx * TP_Multiplier ;
   
         stoploss   = NormalizeDouble(stoploss-1000*Point ,MarketInfo(nomIndice,MODE_DIGITS));
        
         takeprofit = NormalizeDouble(takeprofit+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
         
         size = getSize(POWER, MathAbs((MarketInfo(nomIndice,MODE_ASK) - stoploss)) - 1000 * Point  );
   
         ticketBuy = OrderSend(nomIndice,OP_BUY,setPower(size, LooseRecoveryRatio, WinRecoveryRatio, RecoveryStopper),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,MediumBlue);
   
        
   
         //------------------confirmation du passage ordre Buy-----------------+
   
         if(ticketBuy > 0) 
         {
            if (orx == numberOfOrders) 
            {
               tradeBuy = true; 
               
               
               //------------------------------------------------------+
               // Mando l'ordine al web Server per registrarlo         |
               //------------------------------------------------------+               
               
               if (registerOrders == true) webSendOpenOrder(ticketBuy, 3);



               //------------------------------------------------------+
               // Mando email per comunicare apertura dell'ordine      |
               //------------------------------------------------------+
               if (sendEmailOnOrderOpen == true)
               {
                  bool mailResult = SendMail(bot_name+" ha aperto "+ (string)orx +" posizioni BUY", "Strumento:"+ nomIndice +" -  "+ (string)size);
                  if (mailResult == false) Print("Errore durante invio email BUY: "+ (string)GetLastError());
               }
               
               
            }
         }         else
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
   
      if (t == true) 
      {
         sortieBuy = 0; 
         addOrderToHistory(tkt);  
         
         //------------------------------------------------------+
         // Aggiorno l'ordine sul web Server                     |
         //------------------------------------------------------+               
         if (registerOrders == true) webSendCloseOrder(tkt, 3);
         
         
         ticketBuy = 0;       
         
      }

      else return(-1);
      
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
         
         stoploss   = (High[1] + (SL_added_pips*Point));
         
         
         //TP variabile in base alla posizione rispetto alla media di bollinger
         double middleBand = iBands(nomIndice,0,14,2,0,PRICE_MEDIAN,MODE_MAIN,0);

         tpPaolone = 2;
         
         // applico il moltiplicatore del TP solo se siamo sopra alla media
         // ================= VERSIONE ORIFGINALE =============
         //if ( MarketInfo(nomIndice,MODE_BID) < middleBand ) tpPaolone = autoTargetMultiplier(TP_Paolone_Multiplier);

         // =============== VERSIONE AUTOADATTANTE IN ENTRAMBI I CASI===================
         //tpPaolone = autoTargetMultiplier(TP_Paolone_Multiplier);
         

         takeprofit = MarketInfo(nomIndice,MODE_BID) - tpPaolone*(stoploss - MarketInfo(nomIndice,MODE_BID)) * orx * TP_Multiplier;


         // TP originale
         //takeprofit = MarketInfo(nomIndice,MODE_BID) - (stoploss - MarketInfo(nomIndice,MODE_BID)) * orx * TP_Multiplier; //   Low[1] - ((stoploss - Low[1]) * orx * TP_Multiplier);
         
         stoploss   = NormalizeDouble(stoploss+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
   
         takeprofit = NormalizeDouble(takeprofit-1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
         



         size = getSize(POWER, MathAbs((MarketInfo(nomIndice,MODE_BID) - stoploss)) - 1000*Point);
   
         ticketSell = OrderSend(nomIndice,OP_SELL,setPower(size, LooseRecoveryRatio, WinRecoveryRatio, RecoveryStopper),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,Purple);
   
        
   
         //------------------confirmation du passage ordre Sell-----------------+
   
         if(ticketSell > 0)
         {
            if (orx == numberOfOrders) 
            {
               tradeSell = true; 
               
               
               //------------------------------------------------------+
               // Mando l'ordine al web Server per registrarlo         |
               //------------------------------------------------------+               
               
               if (registerOrders == true) webSendOpenOrder(ticketSell, 3);

               
               //------------------------------------------------------+
               // Mando email per comunicare apertura dell'ordine      |
               //------------------------------------------------------+
               if (sendEmailOnOrderOpen == true)
               {
                  bool mailResult = SendMail(bot_name+" ha aperto "+ (string)orx +" posizioni SELL", "Strumento:"+ nomIndice +" -  "+ (string)size);
                  if (mailResult == false) Print("Errore durante invio email SELL: "+ (string)GetLastError());
               }
               
               
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

      //------------------close ordre sell------------------------------------+
      if (OrderSelect(tkt,SELECT_BY_TICKET)==true)
         lots = OrderLots();     
   
      t = OrderClose(tkt,lots,MarketInfo(nomIndice,MODE_ASK),5,Brown);
      Print("fermetureBuy - ticketSell ",tkt);
   
      //-------------------confirmation du close buy--------------------------+
   
      if (t == true) 
      {
         sortieSell = 0; 
         addOrderToHistory(tkt); 
         
         
         //------------------------------------------------------+
         // Aggiorno l'ordine sul web Server                     |
         //------------------------------------------------------+               
         if (registerOrders == true) webSendCloseOrder(tkt, 3);      
         
         
         
         ticketSell = 0;
      }
      else return(-1);

   }

   return(0);
}

//-----------------end----------------------------------------+



//-------------------------------------------------+
//    VERIFICA DELLA DISTANZA DELLO STOP LOSS
//-------------------------------------------------+
bool getSLDistance(string ot, int minDistance, int maxDistance){
   
   //Print("=========================== Time[0]: "+Time[0]+" - blockedBy_getSLDistance: "+ blockedBy_getSLDistance +" ===========================");
   
   //se questa barra è già stata scartata, restituisco false
   if ( (ot =="BUY") && (iBarShift(nomIndice,0,blockedBy_getSLDistance_for_BUY,false) == 0) )
   {//Print("********************** BUY --- QUESTA BARRA ("+Time[0]+") E' GIA STATA ANALIZZATA E SCARTATA: "+ blockedBy_getSLDistance +" *****************************"); 
   return false;}

   //se questa barra è già stata scartata, restituisco false
   if ( (ot =="SELL") && (iBarShift(nomIndice,0,blockedBy_getSLDistance_for_SELL,false) == 0) )
   {//Print("********************** SELL --- QUESTA BARRA ("+Time[0]+") E' GIA STATA ANALIZZATA E SCARTATA: "+ blockedBy_getSLDistance +" *****************************"); 
   return false;}
   
      
   int SL_Distance = 0;
   // ordine buy
   if (ot == "BUY"){SL_Distance   = (MarketInfo(nomIndice, MODE_ASK) - (MathMin(Low[0],Low[1]) - (SL_added_pips*Point)))/Point;}
   // ordine sell
   if (ot == "SELL") {SL_Distance   = ((MathMax(High[0],High[1]) + (SL_added_pips*Point)) - MarketInfo(nomIndice, MODE_BID))/Point;}
   //Print("getSLDistance("+ot+"): "+(int)SL_Distance);
   
   if (((int)SL_Distance >= minDistance) && ((int)SL_Distance < maxDistance)) {
      return true;}
   else{
      if (ot == "BUY" ){
         // in questa barra non devo PIU aprire trades BUY
         blockedBy_getSLDistance_for_BUY = Time[0];
         //Print("********************** BUY --- La barra delle "+ blockedBy_getSLDistance_for_BUY +" HA SL troppo corto *****************************");
         }
      
      else {
         // in questa barra non devo PIU aprire trades SELL
         blockedBy_getSLDistance_for_SELL = Time[0];
         //Print("********************** SELL --- La barra delle "+ blockedBy_getSLDistance_for_SELL +" HA SL troppo corto *****************************");
      }
      return false;
   }
}


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



// -------------------------------------------------------+
//     VERIFICA ZIGZAG A CAVALLO DI MIDBAND
// -------------------------------------------------------+
bool isGoingUpAndDown(){
   bool upClose = false;
   bool downClose = false;
   bool result = false;
   
   for (int i=0; i<ArraySize(midBand); i++){
      if (Close[i] > midBand[i]) {upClose = true;}
      if (Close[i] < midBand[i]) {downClose = true;}
   }

   if (upClose && downClose) result = true;
   
   return result;
   
}
//-----------------end------------------------------------+ 





// Modifica distanza Take Profit in base agli ordini passati ---------------------------- +
// ======================= VESIONE MODIFICATA CHE SCENDE SOTTO ALL'1:1
/*
double autoTargetMultiplier(double maxMultiplier){

   //se la funzione è disattivata, esco prima di iniziare resituendo il moltiplicatore indicato 
   if (enableAutoProfitMultiplier == false)    return maxMultiplier;
   
   
   // Restituisce un moltiplicatore da usare nell'apertura ordine per calcolare il TP
   // la moltiplicazione in questo sistema parte dal rischio.
   // il moltiplicatore non può mai scendere a 0 (chiuderebbe l'ordine appena aperto)
   // dato il maxMultiplier divido per 10, perchè analizzo 10 ordini storici
   // per ogni ordine in perdita sottraggo un decimo dal maxMultiplier, fino al nono ordine (per non andare a 0)
   // con 0 ordini in perdita, restituisco maxMultiplier
   // con 10 ordini in perdita restituisco 1 decimo del TP originale
   
   int i = 0;
   int o = 0;
   
   double step = 0; // un decimo della distanza tra 0 e maxMultiplier
   step = (maxMultiplier-1)/10;
   step = NormalizeDouble(step,2);

   o = 0; //azzero il contatore
    
   //loop history and get orders of this robot
   for (i=OrdersHistoryTotal()-1; i>=0; i--) 
   {
      if ( (OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true) && (OrderMagicNumber()==SIGNATURE) && (OrderSymbol()==nomIndice) )
      {
         o = o+1;
         if (OrderProfit() <= 0) maxMultiplier = maxMultiplier - step;
         //Scrivo la data dell'ordine
         //Print("autoTargetMultiplier: Order "+OrderTicket() +" Profit "+ OrderProfit() +" - Multiplier: "+maxMultiplier);
         
         if (o == 9) break;
         
      }
      
      if (o == 9) break;
      
   }


   maxMultiplier = NormalizeDouble(maxMultiplier, 2);
   
   // mai minore di 1 (ORIGINALE)
   //if (maxMultiplier < 1) maxMultiplier = 1;
      
   // 27/07/2015 - credo di aver trovato un bug
   // il maxMultiplier dovrebbe essere 1+il numero trovato! Invece era pari al numero trovato!
   // maxMultiplier = 1 + maxMultiplier;
   
   
   //Print("autoTargetMultiplier: ",maxMultiplier );
   return maxMultiplier;

}
*/
 
// ======================== VERSIONE ORIGINALE ======================================
double autoTargetMultiplier(double maxMultiplier){

   //se la funzione è disattivata, esco prima di iniziare resituendo il moltiplicatore indicato 
   if (enableAutoProfitMultiplier == false)    return maxMultiplier;
   
   
   // Restituisce un moltiplicatore da usare nell'apertura ordine per calcolare il TP
   // la moltiplicazione in questo sistema parte dal rischio.
   // il moltiplicatore non può mai essere inferiore ad 1 (R.R = 1:1 minimo)
   // dato il maxMultiplier, sottraggo 1 e divido per 10, perchè analizzo 10 ordini storici
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


   maxMultiplier = NormalizeDouble(maxMultiplier, 2);
   
   // mai minore di 1 (ORIGINALE)
   if (maxMultiplier < 1) maxMultiplier = 1;
   
   // 27/07/2015 - credo di aver trovato un bug
   // il maxMultiplier dovrebbe essere 1+il numero trovato! Invece era pari al numero trovato!
   // maxMultiplier = 1 + maxMultiplier;
   
   
   //Print("autoTargetMultiplier: ",maxMultiplier );
   return maxMultiplier;

}
// ---------------- End of autoTargetMultiplier ----------------------------






// verifica se un ordine raggiunge o supera lo stop loss
bool slReached(int tkt)
{

   //se la funzione è disattivata, esco prima di iniziare
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

   if (result) closeDescription="slReached: raggiunto Stop Loss";

   return result;

}
//-----------------end----------------------------------------+ 



// verifica se un ordine raggiunge o supera il Take Profit
bool tpReached(int tkt)
{

   //se la funzione è disattivata, esco prima di iniziare
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

   if (result) closeDescription="tpReached: raggiunto Take Profit";

   
   return result;

}
//-----------------end----------------------------------------+ 








//--- Verifica se un ordine torna indietro dopo aver visto un certo profitto ----------------------------+ 
// ====================  VERSIONE CHE MANTIENE FISSA LA DISTANZA DELLO SL OLTRE LO ZERO =====================================
/*
bool isCameBack_One(int tkt, int protectionPercent)
{
   // questa versione guarda la distanza originale dello SL dal punto di apertura e fa salire lo SL al salire del prezzo (o scendere per i sell) 
   int shift;
   double profit, max_, min_, hiddener = 0;
   bool result = false;
   double protectionPips = 0;
   hiddener = 1000*Point; // gli SL sono mascheratti
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      profit = MathAbs(OrderOpenPrice() - OrderStopLoss()) - hiddener;  // distanza originale in pip tra apertura e SL
     
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         max_ = High[iHighest(nomIndice,0,MODE_HIGH,shift,0)]; //Print("isCameBack BUY: profit="+profit+" -- max_="+max_+" -- shift="+shift);
         if ( MarketInfo(nomIndice,MODE_BID) <= (max_ - profit) ) // ANCHE OLTRE LO ZERO
         //if ( MarketInfo(nomIndice,MODE_BID) <= MathMin((max_ - profit),OrderOpenPrice()) ) // FINO A ZERO, NON OLTRE
         {result = true; Print("Order Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         min_ = Low[iLowest(nomIndice,0,MODE_LOW,shift,0)]; //Print("isCameBack SELL: profit="+profit+" -- min_="+min_+" -- shift="+shift);
         if ( MarketInfo(nomIndice,MODE_BID) >= (min_ + profit)) // ANCHE OLTRE LO ZERO
         //if ( MarketInfo(nomIndice,MODE_BID) >= MathMax((min_ + profit), OrderOpenPrice()) ) // FINO A ZERO, NON OLTRE
         {result = true; Print("Order Sell ", tkt, " is Coming Back: CHIUDO");}
      }
       
   }
   
   
   if (result) closeDescription="isCameBack: Tornato indietro dopo aver visto un profitto pari al rischio";
   
   return result;

}
//-----------------end----------------------------------------+ 
*/


// ====================== VERSIONE ORIGINALE ====================================
bool isCameBack_One(int tkt, int protectionPercent)
{

   int shift;
   double profit, max_, min_, hiddener = 0;
   bool result = false;
   double protectionPips = 0;
   hiddener = 1000*Point; // gli SL sono mascheratti
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      //se questo ordine ha visto sulla carta un profitto pari al rischio (profit), quando torna indietro lo chiudo a brake even
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      profit = MathAbs(OrderOpenPrice() - OrderStopLoss()) - hiddener;  // tutti gli ordini di un gruppo hanno lo stesso rischio, che è uguale al primo TP
      protectionPips = NormalizeDouble(profit/100*protectionPercent, Digits); // calcolo i pip corrispondenti alla percentuale da proteggere
     
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         max_ = High[iHighest(nomIndice,0,MODE_HIGH,shift,0)]; //Print("isCameBack BUY: profit="+profit+" -- max_="+max_+" -- shift="+shift);
         if ( (max_ - OrderOpenPrice() >= profit) && (MarketInfo(nomIndice,MODE_BID) <= (OrderOpenPrice()+protectionPips) ) )
         {result = true; Print("Order Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         min_ = Low[iLowest(nomIndice,0,MODE_LOW,shift,0)]; //Print("isCameBack SELL: profit="+profit+" -- min_="+min_+" -- shift="+shift);
         if ((OrderOpenPrice() - min_ >= profit) && (MarketInfo(nomIndice,MODE_BID) >= (OrderOpenPrice()-protectionPips) ) )
         {result = true; Print("Order Sell ", tkt, " is Coming Back: CHIUDO");}
      }
       
   }
   
   
   if (result) closeDescription="isCameBack: Tornato indietro dopo aver visto un profitto pari al rischio";
   
   return result;

}
//-----------------end----------------------------------------+ 


bool protector(int tkt,int protectionStart, int protectionClose)
{
   // protectionStart: la percentuale di profitto a cui si attiva il protettore
   // protectionClose: la percentuale che viene protetta, dopo aver raggiunto protectionStart

   int shift;
   double profit, max_, min_, hiddener = 0;
   bool result = false;
   double activationDistance = 0;
   double closeDistance = 0;
   hiddener = 1000*Point; // gli SL sono mascheratti
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      //se questo ordine ha visto sulla carta un profitto pari al rischio (profit), quando torna indietro lo chiudo a brake even
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      profit = MathAbs(OrderOpenPrice() - OrderTakeProfit()) - hiddener;         // Guardo la distanza del TP per proteggerne una percentuale
      activationDistance = NormalizeDouble(profit/100*protectionStart, Digits);  // distanza a cui iniziare a proteggere la posizione, in pips
      closeDistance = NormalizeDouble(profit/100*protectionClose, Digits);       // distanza dello stopProfit, in pips
     
      if ((OrderType() == OP_BUY) && (shift > 0)) // buy order
      {
         max_ = High[iHighest(nomIndice,0,MODE_HIGH,shift,0)]; //Print("isCameBack BUY: profit="+profit+" -- max_="+max_+" -- shift="+shift);
         if ( (max_ - OrderOpenPrice() >= activationDistance) && (MarketInfo(nomIndice,MODE_BID) <= (OrderOpenPrice()+closeDistance) ) )
         {result = true; Print("Order Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if ((OrderType() == OP_SELL) && (shift > 0) ) // sell order
      {
         min_ = Low[iLowest(nomIndice,0,MODE_LOW,shift,0)]; //Print("isCameBack SELL: profit="+profit+" -- min_="+min_+" -- shift="+shift);
         if ((OrderOpenPrice() - min_ >= activationDistance) && (MarketInfo(nomIndice,MODE_BID) >= (OrderOpenPrice()-closeDistance) ) )
         {result = true; Print("Order Sell ", tkt, " is Coming Back: CHIUDO");}
      }
       
   }
   
   
   if (result) closeDescription="isCameBack: Tornato indietro dopo aver visto un profitto pari al rischio";
   
   return result;

}



//--------------- SIZE AUTOMATICA ----------------------------+ 
double getSize(int risk, double distance)
{

   if (usePercentageRisk == false) return POWER;
   
   double equity = AccountEquity();
   double amountRisked = equity/100*risk;
   double finalSize = 0;
   double tickValue = MarketInfo(nomIndice,MODE_TICKVALUE); //valore di un tick con un lotto 
   double minLot = MarketInfo(nomIndice,MODE_MINLOT);
   
   distance = distance/Point; //la distanza deve sempre essere un intero
   
   //amountRisked = MathRound(amountRisked/numberOfOrders); // supporto multiordine, ormai default 1
   
   finalSize = amountRisked/(tickValue*distance);
   
   // arrotondo i lotti in base a quello che può accettare questo strumento
   if (minLot == 1) finalSize = NormalizeDouble(finalSize,0);
   if (minLot == 0.1) finalSize = NormalizeDouble(finalSize,1);
   if (minLot == 0.01) finalSize = NormalizeDouble(finalSize,2);
   
   
   //Print("getSize() - Risk="+(string)risk+" - Distance="+(string)distance+" - amountRisked="+(string)amountRisked+" - finalSize="+(string)finalSize);
   if (finalSize < minLot) finalSize = minLot;
   return finalSize;

}

//-----------------end----------------------------------------+ 



//----------------------------------------------------------------+
//  web request apertura ordine                                   |
// Funzionamento: invia l'apertura di un ordine al web server     |
// con tutti i dati necessari. La procedura è identica per        |
// ordini reali e ordini simulati. Il web server riconosce        |
// la differenza tramite la variabile simulationID.               |
// se è vuota, si tratta di un ordine rale, va in Orders          |
// se è piena l'ordine è una simulazione, va in SimulationsOrders |
//----------------------------------------------------------------+
bool webSendOpenOrder(int tkt, int attempts = 3)
{

      // se non trovo l'ordine mi fermo e lo scrivo
      if (OrderSelect(tkt,SELECT_BY_TICKET)==false) {Alert("webSendOpenOrder: ordine non trovato ("+(string)tkt+")"); return false;}
      
      // encoded strings
      string bot_name_encoded = bot_name; StringReplace(bot_name_encoded, " ", "+");
      string NotesEncoded = Notes; StringReplace(NotesEncoded, " ", "+");
      string orderType = "BUY";  if (OrderType()==1) orderType = "SELL";
      string tpMultiplier = "1";
      
      webRequestBody = 
      "accountID="            +(string)AccountNumber()+
      "&symbol="              +(string)OrderSymbol()+
      "&simulationID="        +(string)simulationID+
      "&botSettings="         +(string)botSettings+"+"+
      "&simulationNotes="     +(string)NotesEncoded+
      "&systemName="          +bot_name_encoded+
      "&systemMagic="         +(string)SIGNATURE+
      "&orderTicket="         +(string)tkt+
      "&orderType="           +orderType+
      "&orderSize="           +(string)OrderLots()+
      "&takeProfit="          +(string)OrderTakeProfit()+
      "&stopLoss="            +(string)OrderStopLoss()+
      "&openTime="            +(string)TimeToStr(OrderOpenTime(),TIME_DATE)+"+"+(string)TimeToStr(OrderOpenTime(),TIME_SECONDS)+
      "&openPrice="           +(string)OrderOpenPrice()+
      "&openPositionAsk="     +(string)MarketInfo(nomIndice,MODE_ASK)+
      "&openPositionBid="     +(string)MarketInfo(nomIndice,MODE_BID)+
      "&tpMultiplier="        +(string)tpPaolone+
      "&point="               +DoubleToString(MarketInfo(OrderSymbol(),MODE_POINT),5)+
      "&tickValue="           +(string)MarketInfo(OrderSymbol(),MODE_TICKVALUE)+
      "&prevVolume="          +(string)Volume[1]+
      
      // aggiungere le informazioni di partenza se necessario
      "&openConditions="+
      "Buy+Conditions:+0."    +(string)buyConditions[0]+"+1."+(string)buyConditions[1]+"+2."+(string)buyConditions[2]+"+3."+(string)buyConditions[3]+"+5."+(string)buyConditions[5]+"+6."+(string)buyConditions[6]+"+7."+(string)buyConditions[7]+"+8."+(string)buyConditions[8]+"+9."+(string)buyConditions[9]+"+10."+(string)buyConditions[10]+"; "+
      "Sell+Conditions:+0."   +(string)sellConditions[0]+"+1."+(string)sellConditions[1]+"+2."+(string)sellConditions[2]+"+3."+(string)sellConditions[3]+"+5."+(string)sellConditions[5]+"+6."+(string)sellConditions[6]+"+7."+(string)sellConditions[7]+"+8."+(string)sellConditions[8]+"+9."+(string)sellConditions[9]+"+10."+(string)sellConditions[10]+"; "+
      "nearestMin:+"          +(string)nearestMin+";+"+
      "nearestMax:+"          +(string)nearestMax+";+"+
      "min:+"                 +(string)min+";+"+
      "max:+"                 +(string)max+";+"+
      "tollerance:+"          +(string)tollerance+";+"
      ;
      
      // invio la richiesta al webServer (provo 10 volte)
      bool res;
      for (int or = 1; or<=attempts ;or++)
      {
         res = sendRequest("http://www.y3web.it/addOrder.asp",webRequestBody,"webSendOpenOrder()",3); 
         if (res) break;
      }

      return res;
}




//----------------------------------------------------------------+
//  web request chiusura ordine                                   |
// Funzionamento: invia la chiusura di un ordine al web server    |
// con tutti i dati necessari. La procedura è identica per        |
// ordini reali e ordini simulati. Il web server riconosce        |
// la differenza tramite la variabile simulationID.               |
// se è vuota, si tratta di un ordine rale, va in Orders          |
// se è piena l'ordine è una simulazione, va in SimulationsOrders |
//----------------------------------------------------------------+
bool webSendCloseOrder(int tkt, int attempts = 3)
{

      // se non trovo l'ordine mi fermo e lo scrivo
      if (OrderSelect(tkt,SELECT_BY_TICKET)==false) {Alert("webSendCloseOrder: ordine non trovato ("+(string)tkt+")"); return false;}
      
      // encoded strings
      string bot_name_encoded = bot_name; StringReplace(bot_name_encoded, " ", "+");
      string orderType = "BUY";  if (OrderType()==1) orderType = "SELL";
      
      // calcolo i pips guadagnati o persi da quest'ordine (mi serve un intero)
      double orderPips = 0;
      
      if (orderType == "BUY")
         orderPips = OrderClosePrice()-OrderOpenPrice();
      else
         orderPips = OrderOpenPrice()-OrderClosePrice();
      
      orderPips = NormalizeDouble(orderPips/Point, Digits);
      
      int cPips = 0, cLib = 0;                  //pips cumulati e valore della libreria
      if (ArraySize(historicPips) > 0)          cPips  = historicPips[ArraySize(historicPips)-1];
      if (ArraySize(historicPipsMA) > 0)        cLib   = historicPipsMA[ArraySize(historicPipsMA)-1];
      
      StringReplace(closeDescription, " ", "+");
      if (StringLen(closeDescription) < 1) closeDescription = "Nessuna+nota+disponibile";
      
      
      webRequestBody = 
      "accountID="            +(string)AccountNumber()+
      "&symbol="              +(string)OrderSymbol()+
      "&simulationID="        +(string)simulationID+
      "&orderTicket="         +(string)tkt+
      "&closeTime="           +(string)TimeToStr(OrderCloseTime(),TIME_DATE)+"+"+(string)TimeToStr(OrderCloseTime(),TIME_SECONDS)+
      "&closePrice="          +(string)OrderClosePrice()+
      "&closePositionAsk="    +(string)MarketInfo(nomIndice,MODE_ASK)+
      "&closePositionBid="    +(string)MarketInfo(nomIndice,MODE_BID)+    
      "&pips="                +(string)orderPips+
      "&cumulativePips="      +(string)cPips+
      "&cumulativeGau="       +(string)cLib+
      "&orderProfit="         +(string)OrderProfit()+
      
      // aggiungere le informazioni di partenza se necessario
      "&closeConditions="     +closeDescription
      ;
      
      //Print(webRequestBody);
      
      // invio la richiesta al webServer (provo 10 volte)
      bool res;
      for (int or = 1; or<=attempts ;or++)
      {
         res = sendRequest("http://www.y3web.it/closeOrder.asp",webRequestBody,"webSendCloseOrder()",3); 
         if (res) break;
      }

      return res;
}



//-------------------prints------------------------------+

int commentaire()

   {

   int cPips = 0, cLib = 0; //pips fatti e valore della libreria
   if (ArraySize(historicPips) > 0) cPips = historicPips[ArraySize(historicPips)-1];
   if (ArraySize(historicPipsMA) > 0) cLib = historicPipsMA[ArraySize(historicPipsMA)-1];
   

    Comment( "\n ","\n ","\n ","\n ",
            "\n ",bot_name, ": ",nomIndice,

            "\n ",
            
            "\n Base POWER: ",POWER,
            
            "\n SL Added Pips: ",SL_added_pips,
            
            "\n Base TPMultip.: ",TP_Paolone_Multiplier,
            
            "\n ",
            
            "\n TRADES: ",ArraySize(historicPips),
            
            "\n ",
            
            //"\n Pips / LIB: ",(string)cPips, " / ", (string)cLib,
            
            //"\n Next Order TPMultip.: ",autoTargetMultiplier(TP_Paolone_Multiplier),
            
            //"\n Periods Base / Adaptive: ",Y3_POWER_LIB_maPeriod ," / ", adaptive_maPeriod,
            
            //"\n Next Order Size: ",setPower(POWER, LooseRecoveryRatio, WinRecoveryRatio, RecoveryStopper),

           // "\n Orari: ",openHours,
            
            "\n +-----------------------------   ",
            "\n BUY Conditions   : 0.",buyConditions[0]," 1.",buyConditions[1]," 2.",buyConditions[2]," 3.",buyConditions[3]," 4.",buyConditions[4]," 5.",buyConditions[5]," 6.",buyConditions[6]," 7.",buyConditions[7],
            "\n SELL Conditions  : 0.",sellConditions[0]," 1.",sellConditions[1]," 2.",sellConditions[2]," 3.",sellConditions[3]," 4.",sellConditions[4]," 5.",sellConditions[5]," 6.",sellConditions[6]," 7.",sellConditions[7],
            "\n +-----------------------------   ",
            "\n Time: ",TimeCurrent(),


            "");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+