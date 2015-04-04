//+------------------------------------------------------------------+
//| v 0.1 beta                                                       |
//|                                              http://www.y3web.it |
//| DEFAULT: DA TESTARE                                              |
//+------------------------------------------------------------------+

// Basato sul Volatility System di J. Welles Wilder Jr. - pag 23 di NEW CONCEPTS IN TECHNICAL TRADING SYSTEMS
// è un true reverse: quando chiude un buy, apre un sell e viceversa
// il manuale dice di usarlo su grafici D1
// dovrebbe agire solo all'apertura di una nuova barra
 


//--------Index name------+

string nomIndice = "EURUSD"; //sovrascritto dopo in init()
 

//--------number of lots to trade--------------+
extern int SIGNATURE = 0017000;
extern string COMMENT = "SYSTEM";
extern double POWER = 0.1;
extern int period = 7;
extern int C = 3;
extern double TP_Multiplier = 3; // imposta il rapporto rischio/rendimento. da 1:1 in su
extern int numberOfOrders = 1; //usato per decidere quanti ordini aprire per ogni posizione. Moltiplica anche la distanza del TP (x1, x2, x3 etc)
extern int SL_added_pips = 10; // distanza in pip da aggiungere allo SL. Lo SL è uguale al massimo(minimo) della barra precedente + questo numero di pips. Così è gestibile per ogni strumento.
extern string nameOfHistoryFile = "XXX_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 3;
extern bool enablePowerLIB = false;


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

bool buyConditions[10]; 
bool sellConditions[10]; 

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
   
   // inizializzo atr
   atr = iATR(nomIndice,0,period,1);
   

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

//----

   return(0);

  }

//+------------------------------------------------------------------+

//| expert start function                                            |

//+------------------------------------------------------------------+

int start()

  {

//----
if (Volume[0] < 10)
{
   paramD1();

   ouvertureBuy();

//   fermetureBuy();

   ouvertureSell();

//   fermetureSell();

   commentaire();
//----
}
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


      atr = iATR(nomIndice,0,period,1); //atr = getATR(period);
      ARC = C * atr;
      maxSAR = getSIC(period,"min") + ARC;
      minSAR = getSIC(period,"max") - ARC;
      drawSAR(maxSAR, minSAR);



//-----------------enter buy order---------------------------+

   
   if( Close[1] > maxSAR)                     buyConditions[0] = true; // se passiamo oltre al maxSAR entriamo in long
   if( existOrder(0) < 0)                     buyConditions[1] = true; // non ho un altro ordine buy attivo

   
   if(
       (buyConditions[0]) 
      && (buyConditions[1])  
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

if (sortieBuy == 0)
   {//scorrere gli ordini per vedere se uno va chiuso
   for(int pos=0;pos<OrdersTotal();pos++)
       {
        if( (OrderSelect(pos,SELECT_BY_POS)==false)
        || (OrderSymbol() != nomIndice)
        || (OrderMagicNumber() != SIGNATURE)
        || (OrderType() != 0)) continue;
        
        // Print("Trovato Ordine Buy da controllare : ",OrderTicket());
        
        //clausole di chiusura
        if ((Close[1] < minSAR)                                                  // Il prezzo scende sotto al minSAR
//          ||(MarketInfo(nomIndice,MODE_ASK) < OrderStopLoss() + (1000*Point))    // Raggiunto SL
//          ||(MarketInfo(nomIndice,MODE_ASK) > OrderTakeProfit() - (1000*Point))  // Raggiunto TP
           )
        {
         sortieBuy = OrderTicket();       
         Print("Trovato Ordine Buy da chiudere: ",OrderTicket());

         fermetureBuy(OrderTicket());
        }

       }
   
   }


//-----------------end---------------------------------------------+





//-----------------enter sell order----------------------------+



   if ( Close[1] < minSAR)                                sellConditions[0] = true; // la barra di ieri ha chiuso sotto al minSAR
   if( existOrder(1) < 0)                                 sellConditions[1] = true; // non ho altri ordini sell attivi
   
   
   if(
         (sellConditions[0])  
      && (sellConditions[1])  
     )

   {

      entreeSell = true; 
      //Print("SELL - b:",b," - a:",a);
   }
   

//-----------------end---------------------------------------------+
 
//-----------------exit sell orders---------------------------+

if (sortieSell == 0)
   {//scorrere gli ordini per vedere se uno va chiuso
   for(pos=0;pos<OrdersTotal();pos++)
       {
        if( (OrderSelect(pos,SELECT_BY_POS)==false)
        || (OrderSymbol() != nomIndice)
        || (OrderMagicNumber() != SIGNATURE)
        || (OrderType() != 1)) continue;
        
        //Print("Trovato Ordine Sell da controllare : ",OrderTicket());
        
        //clausole di chiusura
        if ( (Close[1] > maxSAR)                                                // Superato maxSAR
//          ||(MarketInfo(nomIndice,MODE_ASK) > OrderStopLoss() - (1000*Point))   // Raggiunto SL
//          ||(MarketInfo(nomIndice,MODE_ASK) < OrderTakeProfit() + (1000*Point)) // Raggiunto TP
          )
        {
         sortieSell = OrderTicket();       
         Print("Trovato Ordine Sell da chiudere: ",OrderTicket());

         fermetureSell(OrderTicket());
        }

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
  

   
   // per aprire più ordini uso la variabile numberOfOrders
   for (int orx=1;orx<=numberOfOrders;orx++)
   {
      if(entreeBuy == true)

      {  
         /*
         stoploss   = (Low[1] - (SL_added_pips*Point));
   
         takeprofit = High[1] + ((High[1] - stoploss) * orx * TP_Multiplier) ;
   
         stoploss   = NormalizeDouble(stoploss-10000*Point ,MarketInfo(nomIndice,MODE_DIGITS));
   
         takeprofit = NormalizeDouble(takeprofit+10000*Point,MarketInfo(nomIndice,MODE_DIGITS));
         */
        
   
         ticketBuy = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,MediumBlue);
   
        
   
         //------------------confirmation du passage ordre Buy-----------------+
   
         if(ticketBuy > 0) 
            {if (orx == numberOfOrders) tradeBuy = true;}
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

   double stoploss, takeprofit;

  
   // per aprire più ordini uso la variabile numberOfOrders
   for (int orx=1;orx<=numberOfOrders;orx++)
   {
      if(entreeSell == true)
   
      {
         /* 
         stoploss   = (High[1] + (SL_added_pips*Point));
   
         takeprofit = Low[1] - ((stoploss - Low[1]) * orx * TP_Multiplier);
         
         stoploss   = NormalizeDouble(stoploss+10000*Point,MarketInfo(nomIndice,MODE_DIGITS));
   
         takeprofit = NormalizeDouble(takeprofit-10000*Point,MarketInfo(nomIndice,MODE_DIGITS));
         */
        
   
         ticketSell = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,Purple);
   
        
   
         //------------------confirmation du passage ordre Sell-----------------+
   
         if(ticketSell > 0)
            {if (orx == numberOfOrders) tradeSell = true;}
         else
            {orx--;}
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


//--- Verifica se un ordine torna indietro dopo aver visto un certo profitto ----------------------------+ 

bool isCameBack(int tkt)
{

   int shift;
   double profit, max_, min_;
   bool result = false;
   
   if (OrderSelect(tkt, SELECT_BY_TICKET)==true) 
   {
      //se questo ordine ha visto sulla carta un profitto pari al rischio (profit), quando torna indietro lo chiudo a brake even
      
      shift = iBarShift(nomIndice,0,OrderOpenTime(),false);
      shift++; // il segnale è la barra precedente all'ordine
      profit = MathAbs(High[shift]-Low[shift]);
      
     
      if (OrderType() == OP_BUY) // buy order
      {
         max_ = High[iHighest(nomIndice,0,MODE_HIGH,shift,0)];
         if ( (max_ - OrderOpenPrice() >= profit) && (MarketInfo(nomIndice,MODE_BID) <= OrderOpenPrice()))
         {result = true; Print("Order Buy ", tkt, " is Coming Back: CHIUDO");}
      }

 
      if (OrderType() == OP_SELL) // sell order
      {
         min_ = Low[iLowest(nomIndice,0,MODE_LOW,shift,0)];
         if ((OrderOpenPrice() - min_ >= profit) && (MarketInfo(nomIndice,MODE_BID) >= OrderOpenPrice()))
         {result = true; Print("Order Sell ", tkt, " is Coming Back: CHIUDO");}
      }
       
   }
      return result;

}
//-----------------end----------------------------------------+ 



//---------STARTING ATR CALCULATION WITH JWW ORIGINAL METHOD------------+ 
double getATR(int t){
   
   double a, b, c, dailyATR, jww_atr;
   jww_atr = 0;
   
   for(int j=2; j<=(t+1); j++){
   
      a = High[t] - Low[t];
      b = High[t] - Close[t+1];
      c = Close[t+1] - Low[t];
      
      //prendo il valore massimo tra quelli analizzati
      dailyATR = MathMax(a,b);
      dailyATR = MathMax(dailyATR,c);
      
      //sommo l'atr ai precedenti
      jww_atr = jww_atr + dailyATR;
   }
   
   //atr è la media di questi valori
   jww_atr = jww_atr/t;
   
   return jww_atr;
   
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

            "\n ATR            : ",atr,
            "\n maxSAR            : ",getSIC(period,"min"),"+",C,"*",atr," = ",maxSAR,
            "\n minSAR            : ",getSIC(period,"max"),"-",C,"*",atr," = ",minSAR,
            
            "\n +-----------------------------   ",
            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],
            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],
            "\n +-----------------------------   ",


            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+