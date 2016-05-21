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
string bot_name = "Vidocq 0.2.0 - Supertrend Lib"; // Supertrend
string botSettings; //contiene i settaggi del Bot


//--------Index name------+
string nomIndice = "GER30"; //sovrascritto dopo in init()
                          
//--------number of lots to trade--------------+
extern string ext_bot_settings = "=============== Bot Settings ===============";
extern int SIGNATURE = 0018000;
extern string COMMENT = "Vidocq";
extern string nameOfHistoryFile = "Vidocq_HST_";

extern string ext_trade_settings = "=============== Trade Settings ===============";
extern double POWER = 0.1;                                                              
extern string startingHour = "00:00";           /*startingHour: orario inizio attività*/        
extern string endingHour = "23:59";             /*endingHour: orario di fine attività*/         
//extern int SL_added_pips = 2;                   /*SL_added_pips: pip da aggiungere allo SL*/    
extern int LooseRecoveryRatio = 0;            /*Loose RecoveryRatio (%)*/                     
extern int WinRecoveryRatio = 0;              /*Win RecoveryRatio (%)*/                       
extern double RecoveryStopper = 0.1;            /*Recover Stopper (0.0 - 1.0)*/                 
extern int nFast = 3;                           /*AMA nFast*/
extern int min_SL_Distance = 0;                 /*min. Stop Loss Distance*/
extern int max_SL_Distance = 10000;             /*max. Stop Loss Distance*/
extern int protectionStartDistance = 90;        /*Cameback % Start*/
extern int protectionCloseDistance = 80;           /*Cameback % Protection*/
extern int atrMultiplier = 2;
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

//variabili per determinare il dateTime esatto della barra di apertura di oggi.
datetime tm, startTime, endTime;

double tpPaolone = 1; //usato nell'inserimento ordini, necessario per avere il valore dopo l'inserimento dell'ordine

bool enabledHours[24]; // array con le singole ore in cui c'è indicato se tradare o no (true o false)


bool buyConditions[20]; 
bool sellConditions[20]; 
string closeDescription; // per sapere perchè ha chiuso un ordine e scriverlo sul web Server


datetime lastAnalizedBarTime;       // per eseguire alcuni controlli una sola volta per barra: inizializzato in init
datetime blockedBy_getSLDistance_for_BUY;   // getSLDistance salva qui il Time[] dell'ultima barra bloccata da lui
datetime blockedBy_getSLDistance_for_SELL;   // getSLDistance salva qui il Time[] dell'ultima barra bloccata da lui
bool webBarDataSendedToServer;      // gestisce se inviare o no i dati iniziali di una barra al webServer
int simulationID;                   // serve per scrivere un ID univoco nella simulazione sul web server per distinguerle
//+--------------- Include ------------------------+

//#include  "Y3_POWER_LIB.mqh"
//#include  "Y3_POWER_LIB_Recovery.mqh"
#include  "Y3_POWER_SUPERTREND.mqh"
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
   //botSettings += "SL_added_pips:+"+(string)SL_added_pips+",+";     
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
   botSettings += "atrMultiplier:+"+(string)atrMultiplier+",+";
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
   
   
   if (iBarShift(nomIndice,0,lastAnalizedBarTime,false) > 0 ) //(Volume[0] == 1)
   {
      

      //aggiorno lastAnalizedBarTime in modo che fino alla prossima barra tutto questo non venga eseguito
      lastAnalizedBarTime = Time[0];

      // dico al bot che deve ancora spedire i dati iniziali di questa barra al webServer
      webBarDataSendedToServer = false; 
      
   }
   

//-----------------enter buy order---------------------------+

   // buyConditions array
   
   
   if (Close[1] > Open[1])                                     buyConditions[0] = true;   // la barra precedente è BULL
   if (!existOrderOnThisBar(0))                                buyConditions[1] = true;   // se NON ho un ordine già aperto in questa barra (apre un solo ordine per ogni direzione)
   if (enabledHours[Hour()] == true)                           buyConditions[2] = true;   // A questa ora posso tradare
   if (!existOpendedAndClosedOnThisBar(1))                     buyConditions[3] = true;   // Se non ho 1 ordine aperto e chiuso in questa barra
   if (existOrder(0) < 0)                                      buyConditions[4] = true;   // non ho già un ordine aperto in questa direzione (apre un solo ordine per direzione)
   //if ( (Close[0] < midBand[0]) )                              buyConditions[2] = true;   // il prezzo attuale è sotto alla middle band di Bollinger
   //if (getSLDistance("BUY", min_SL_Distance, max_SL_Distance)) buyConditions[4] = true;   // lo SL è almeno distante quanto richiesto
   //if (isGoingUpAndDown())                                     buyConditions[6] = true;   // se almeno una delle ultime 10 barre chiudeva sopra a midBand (sto zigzagando)
   
   //if ((Close[0] < trendUp) && (trendUp != EMPTY_VALUE))     buyConditions[9] = true;   // Solo se il trend daily è UP - CON BUG
   //if ((Close[0] > trendUp) && (trendUp != EMPTY_VALUE))       buyConditions[9] = true;   // Solo se il trend daily è UP - SENZA BUG
   // if (Close[0] < upperband[0])                             buyConditions[10] = true;  // Non sono salito oltre la upperBand - abbastanza inconcludente nel 2010
   //if (Close[0] > lowerEnvelope)                               buyConditions[11] = true;  // Solo se non scende sotto al lower envelope
   

   
   if(   (buyConditions[0]) 
      && (buyConditions[1]) 
      && (buyConditions[2]) 
      && (buyConditions[3])
      && (buyConditions[4])
      //&& (buyConditions[5]) 
      //&& (buyConditions[6]) 
      //&& (buyConditions[7]) 
      //&& (buyConditions[8]) 
      //&& (buyConditions[9])       
      //&& (buyConditions[10])       
      //&& (buyConditions[11])
   )
   {
         entreeBuy = true; 
   }

   
//-----------------end---------------------------------------------+




//-----------------exit buy orders---------------------------+


//scorrere gli ordini per vedere se uno va chiuso
for(int pos=0;pos<OrdersTotal();pos++)
    {
     if( (OrderSelect(pos,SELECT_BY_POS)==false)
     || (OrderSymbol() != nomIndice)
     || (OrderMagicNumber() != SIGNATURE)
     || (OrderType() != 0)) continue;
     
     
     //clausole di chiusura
     if (//(isCameBack_One(OrderTicket(), 0))                                                        // se dopo aver visto un profitto di 1:1 torna indietro
        (protector(OrderTicket(), protectionStartDistance, protectionCloseDistance))             // se ha raggiunto una certa percentuale di profitto e poi torna indietro
       || (slReached(OrderTicket()))                                                               // Raggiunto SL
       || (tpReached(OrderTicket()))                                                               // Raggiunto TP
     )
     {
      sortieBuy = OrderTicket();       

      fermetureBuy(OrderTicket());
     }

    }
   


//-----------------end---------------------------------------------+





//-----------------enter sell order----------------------------+
   // sellConditions array
   if (Close[1] < Open[1])                                     sellConditions[0] = true;   // La barra precedente è BEAR
   if (!existOrderOnThisBar(1))                                sellConditions[1] = true;   // se NON ho un ordine già aperto in questa barra (apre più ordini in ogni direzione)
   if (enabledHours[Hour()] == true)                           sellConditions[2] = true;   // A questa ora posso tradare
   if (!existOpendedAndClosedOnThisBar(1))                     sellConditions[3] = true;   // Se non ho 1 ordine aperto e chiuso in questa barra   
   if (existOrder(1) < 0 )                                     sellConditions[4] = true;     // non ho già un ordine attivo in questa direzione (apre un solo ordine per direzione)
   //if (Close[0] > midBand[0])                                sellConditions[2] = true;   // il prezzo attuale è sopra alla middle band di Bollinger
   //if (getSLDistance("SELL", min_SL_Distance, max_SL_Distance))sellConditions[4] = true;   // lo SL è almeno distante quanto richiesto
   //if (isGoingUpAndDown())                                     sellConditions[6] = true;   // se almeno una delle ultime 10 barre chiudeva sopra a midBand (sto zigzagando)
   //if ((Close[0] > trendDown) && (trendDown != EMPTY_VALUE))   sellConditions[9] = true;   // Solo se il trend daily è DOWN - CON BUG
   //if ((Close[0] < trendDown) && (trendDown != EMPTY_VALUE))   sellConditions[9] = true;   // Solo se il trend daily è DOWN - SENZA BUG
   //if (Close[0] > lowerBand[0])                                sellConditions[10] = true;  // Non sono sceso oltre la lowerBand - abbastanza inconcludente nel 2010
   //if (Close[0] < upperEnvelope)                               sellConditions[11] = true;  // Solo se non sale oltre all'upper envelope

   
   if(   (sellConditions[0])
      && (sellConditions[1]) 
      && (sellConditions[2])
      && (sellConditions[3])
      && (sellConditions[4])
      //&& (sellConditions[5]) 
      //&& (sellConditions[6]) 
      //&& (sellConditions[7]) 
      //&& (sellConditions[8])
      //&& (sellConditions[9])
      //&& (sellConditions[10]) 
      //&& (sellConditions[11]) 
      
   )
   {
      entreeSell = true; 
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
     
     
     //clausole di chiusura
     if (// (isCameBack_One(OrderTicket(), 0))                                                       // se dopo aver visto un profitto di 1:1 torna indietro
        (protector(OrderTicket(), protectionStartDistance, protectionCloseDistance))             // se ha raggiunto una certa percentuale di profitto e poi torna indietro
       || (slReached(OrderTicket()))                                                               // Raggiunto SL
       || (tpReached(OrderTicket()))                                                               // Raggiunto TP
       )
     {
      sortieSell = OrderTicket();       


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
      "Sell+Conditions:+0."   +(string)sellConditions[0]+"+1."+(string)sellConditions[1]+"+2."+(string)sellConditions[2]+"+3."+(string)sellConditions[3]+"+4."+(string)sellConditions[4]+"+5."+(string)sellConditions[5]+"+6."+(string)sellConditions[6]+"+7."+(string)sellConditions[7]+"+8."+(string)sellConditions[8]+"+9."+(string)sellConditions[9]+";+"+(string)sellConditions[10]+";+"
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
         
         stoploss   = getSL("BUY", atrMultiplier); 
   
         takeprofit = getTP("BUY", 2*atrMultiplier);
   
         stoploss   = NormalizeDouble(stoploss-1000*Point ,MarketInfo(nomIndice,MODE_DIGITS));
        
         takeprofit = NormalizeDouble(takeprofit+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
         
         size = POWER; //getSize(POWER, MathAbs((MarketInfo(nomIndice,MODE_ASK) - stoploss)) - 1000 * Point  );
   
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
         
         stoploss   = getSL("SELL", atrMultiplier); //(High[1] + (SL_added_pips*Point));
         
         takeprofit = getTP("SELL", 2*atrMultiplier);
         
         stoploss   = NormalizeDouble(stoploss+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
   
         takeprofit = NormalizeDouble(takeprofit-1000*Point,MarketInfo(nomIndice,MODE_DIGITS));

         size = POWER; //getSize(POWER, MathAbs((MarketInfo(nomIndice,MODE_BID) - stoploss)) - 1000*Point);
   
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
//    CALCOLO TP 
//-------------------------------------------------+
double getTP(string direction = "BUY", int multiplier = 1){
   
   double atrValue = iATR(nomIndice,PERIOD_CURRENT, 100, 0); //atr 14 orario
   double result = 0;
   if (direction == "BUY"){
      result = Close[0] + multiplier*atrValue;
   }
   else{
      result = Close[0] - multiplier*atrValue;
   }
   
   return result;
}

//-------------------------------------------------+
//    CALCOLO SL 
//-------------------------------------------------+
double getSL(string direction = "BUY", int multiplier = 1){
   
   double atrValue = iATR(nomIndice,PERIOD_CURRENT, 100, 0); //atr 14 orario
   double result = 0;
   if (direction == "BUY"){
      result = Close[0] - multiplier*atrValue;
   }
   else{
      result = Close[0] + multiplier*atrValue;
   }
   
   return result;
}


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
   if (ot == "BUY"){SL_Distance   = (MarketInfo(nomIndice, MODE_ASK) - (MathMin(Low[0],Low[1])))/Point;}
   // ordine sell
   if (ot == "SELL") {SL_Distance   = ((MathMax(High[0],High[1])) - MarketInfo(nomIndice, MODE_BID))/Point;}
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
         if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderCloseTime() == 0))         
         /*if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == 0) && (OrderCloseTime() == 0) && (ot == 0) )         
         return OrderTicket();
         if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderType() == 1) && (OrderCloseTime() == 0) && (ot == 1) )         
         */
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
         if (MarketInfo(nomIndice,MODE_BID) <= OrderTakeProfit() + hiddener)
         {result = true; Print("tpReached: SELL order ", tkt, " - CHIUDERE");}
      }
       
   }

   if (result) closeDescription="tpReached: raggiunto Take Profit";

   
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
      "Sell+Conditions:+0."   +(string)sellConditions[0]+"+1."+(string)sellConditions[1]+"+2."+(string)sellConditions[2]+"+3."+(string)sellConditions[3]+"+5."+(string)sellConditions[5]+"+6."+(string)sellConditions[6]+"+7."+(string)sellConditions[7]+"+8."+(string)sellConditions[8]+"+9."+(string)sellConditions[9]+"+10."+(string)sellConditions[10]+"; "
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

            "\n ",
            
            //"\n Pips / LIB: ",(string)cPips, " / ", (string)cLib,
            
            //"\n Next Order TPMultip.: ",autoTargetMultiplier(TP_Paolone_Multiplier),
            
            //"\n Periods Base / Adaptive: ",Y3_POWER_LIB_maPeriod ," / ", adaptive_maPeriod,
            
            //"\n Next Order Size: ",setPower(POWER, LooseRecoveryRatio, WinRecoveryRatio, RecoveryStopper),

           // "\n Orari: ",openHours,
/*            
            "\n +-----------------------------   ",
            "\n BUY Conditions   : 0.",buyConditions[0]," 1.",buyConditions[1]," 2.",buyConditions[2]," 3.",buyConditions[3]," 4.",buyConditions[4]," 5.",buyConditions[5]," 6.",buyConditions[6]," 7.",buyConditions[7],
            "\n SELL Conditions  : 0.",sellConditions[0]," 1.",sellConditions[1]," 2.",sellConditions[2]," 3.",sellConditions[3]," 4.",sellConditions[4]," 5.",sellConditions[5]," 6.",sellConditions[6]," 7.",sellConditions[7],
            "\n +-----------------------------   ",
            "\n Time: ",TimeCurrent(),
*/

            "");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+