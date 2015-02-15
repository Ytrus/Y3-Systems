//+------------------------------------------------------------------+
//| v 0.1 beta                                                       |
//|                                              http://www.y3web.it |
//| DEFAULT: DA TESTARE                                              |
//+------------------------------------------------------------------+

// Apre una posizione quando si rompe un minimo(massimo) locale tornando in direzione di trend. Per vedere il trend si usano due medie mobili: 21 e 100.
// Non gestisce la posizione una volta aperta.
// permette di aprire posizioni su posizioni: ognuna ha il suo TP e SL, che agiscono da soli.
// lo SL è sopra(sotto) il massimo(minimo) locale.
// Il TP è n volte distante lo SL. n è gestito come vaqriabile input

//TODO: Provare a gestire gli ordini barra per barra.
// Con una sola media mobile veloce: aprire su ogni rottura ribassista (non parlo di tiracciamenti: si compra su OGNI rottura!) se sotto di essa e su ogni rottura rialzista, se sopra ad essa. Chiudere al minimo(massimo) della barra precedente OPPURE quando si tocca la media.
// gestire dimensione lotti automatica al 2% del capitale.
 


//--------Index name------+

string nomIndice = "EURUSD"; //sovrascritto dopo in init()
 

//--------number of lots to trade--------------+
extern int SIGNATURE = 0016000;
extern string COMMENT = "SYSTEM";
extern double POWER = 0.1;
extern int numberOfOrders = 3; //usato per decidere quanti ordini aprire per ogni posizione. Moltiplica anche la distanza del TP (x1, x2, x3 etc)
extern double TP_Multiplier = 3; // imposta il rapporto rischio/rendimento. da 1:1 in su
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

double atr;



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
   
   
   initY3_POWER_LIB(nameOfHistoryFile,SIGNATURE,Y3_POWER_LIB_maPeriod,enablePowerLIB);
   

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

   
   double a, b, plusDI, minusDI, ADx;   

   entreeBuy  = false;
   
   entreeSell = false;
   
   ArrayInitialize(buyConditions,false);   //Array buyConditions per debuggare
   ArrayInitialize(sellConditions,false);   //Array sellConditions per debuggare

   ADx = iADX(nomIndice,0,21,PRICE_CLOSE,0,1);
   plusDI = iADX(nomIndice,0,14,PRICE_CLOSE,1,1);
   minusDI = iADX(nomIndice,0,14,PRICE_CLOSE,2,1);

   atr = iATR(nomIndice,0,100,1); //al momento uso un decomo di atr come massimo scostamento dal massimo(minimo) precedenti per sapere se entrare in un trade magari già chiuso poco fa.



//-----------------enter buy order---------------------------+

   a = iMA(nomIndice,0,21,0,MODE_EMA,PRICE_MEDIAN,0);
   b = iMA(nomIndice,0,100,0,MODE_EMA,PRICE_MEDIAN,0);
   
   if( a > b)                                      buyConditions[0] = true; // trend up
   if (chk_ordersOnThisBar(ticketBuy) == false)    buyConditions[1] = true; // non ho già inserito un ordine in questa barra
   if (Low[1] < Low[2])                            buyConditions[2] = true; // il minimo di ieri è inferiore a quello di ieri l'altro
   if (High[1] <= High[2])                         buyConditions[3] = true; // il massimo di ieri è inferiore a quello di ieri l'altro
   if (Close[0] > High[1])                         buyConditions[4] = true; // il prezzo attuale è superiore al massimo di ieri
   if (Close[0] < High[1] + (atr/10) )             buyConditions[5] = true; // non siamo troppo in alto
   if (plusDI > minusDI)                           buyConditions[6] = true; // ADX +DI > -DI
   if (High[0]-High[1] < High[1]-Low[1])           buyConditions[7] = true; // Se il massimo di oggi non ha superato il profitto numero 1
   if (ADx > 20)                                   buyConditions[8] = true; // ADX > 20
   //if (Close[0] > b)                             buyConditions[9] = true; // Il prezzo è sopra alla media lenta
   if (Close[0] > a)                               buyConditions[9] = true; // Il prezzo è sopra alla media veloce
   //&&(High[1] < High[2]) // il massimo di ieri è inferiore al massimo di ieri l'altro
   //&&(High[0] < High[1]+10*Point) // non siamo oltre i 10 pips dal massimo di ieri
   
   if(
      // (buyConditions[0]) 
         (buyConditions[1])  
      && (buyConditions[2])  
      && (buyConditions[3])  
      && (buyConditions[4])  
      && (buyConditions[5])  
      //&& (buyConditions[6])  
      && (buyConditions[7])  
      //&& (buyConditions[8])  
      && (buyConditions[9])  
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
        if ((MarketInfo(nomIndice,MODE_ASK) < OrderStopLoss() + (1000*Point))
          ||(MarketInfo(nomIndice,MODE_ASK) > OrderTakeProfit() - (1000*Point))
          || (isCameBack(OrderTicket()) && (numberOfOrders > 1))
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



   if ( a < b)                                     sellConditions[0] = true; // trend down
   if (chk_ordersOnThisBar(ticketSell) == false)   sellConditions[1] = true; // non ho già inserito un ordine in questa barra
   if (High[1] > High[2])                          sellConditions[2] = true; // il massimo di ieri è superiore al massimo di ieri l'altro
   if (Low[1] >= Low[2])                           sellConditions[3] = true; // il minimo di ieri è superiore al massimo di ieri l'altro
   if (Close[0] < Low[1])                          sellConditions[4] = true; // il prezzo attuale è inferiore al minimo di ieri
   if (Close[0] > Low[1] - (atr/10))               sellConditions[5] = true; // Non siamo troppo in basso...
   if (plusDI < minusDI)                           sellConditions[6] = true; // ADX +DI < -DI
   if (Low[1]-Low[0] < High[1]-Low[1])             sellConditions[7] = true; // Se il minimo di oggi non ha superato il profitto numero 1
   if (ADx > 20)                                   sellConditions[8] = true; // ADX > 20
   //if (Close[0] < b)                             sellConditions[9] = true; // Il prezzo è sotto alla media lenta
   if (Close[0] < a)                               sellConditions[9] = true; // Il prezzo è sotto alla media veloce
   
   
   if(
      // (sellConditions[0])  
         (sellConditions[1]) 
      && (sellConditions[2]) 
      && (sellConditions[3]) 
      && (sellConditions[4]) 
      && (sellConditions[5]) 
      //&& (sellConditions[6]) 
      && (sellConditions[7]) 
      //&& (sellConditions[8]) 
      && (sellConditions[9]) 
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
        if ((MarketInfo(nomIndice,MODE_ASK) > OrderStopLoss() - (1000*Point))
          ||(MarketInfo(nomIndice,MODE_ASK) < OrderTakeProfit() + (1000*Point))
          ||(isCameBack(OrderTicket()) && (numberOfOrders > 1))
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

      {   stoploss   = (Low[1] - (SL_added_pips*Point));
   
         takeprofit = High[1] + ((High[1] - stoploss) * orx * TP_Multiplier) ;
   
         stoploss   = NormalizeDouble(stoploss-1000*Point ,MarketInfo(nomIndice,MODE_DIGITS));
   
         takeprofit = NormalizeDouble(takeprofit+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
   
        
   
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
         
         stoploss   = (High[1] + (SL_added_pips*Point));
   
         takeprofit = Low[1] - ((stoploss - Low[1]) * orx * TP_Multiplier);
         
         stoploss   = NormalizeDouble(stoploss+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
   
         takeprofit = NormalizeDouble(takeprofit-1000*Point,MarketInfo(nomIndice,MODE_DIGITS));
   
        
   
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

   if (t == true) {sortieSell = 0; addOrderToHistory(tkt); ticketSell = 0; }

   }

   return(0);
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
      
      /*
      int total = OrdersTotal();
      mn = SIGNATURE;
      s = nomIndice;
      
      for(int pos=0;pos<total;pos++)
      {
         if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
         if ((OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && ((OrderType() == 0) || (OrderType() == 1)) && (OrderCloseTime() == = 0) )
         
         return true;
      }
      
      return false;      
      */
   
   }
//-----------------end----------------------------------------+ 


//--- Verifica se un ordine torna indietro dopo aver fisto un certo profitto ----------------------------+ 

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
       
      return result;
   }

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
            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],buyConditions[2],buyConditions[3],buyConditions[4],buyConditions[5],buyConditions[6],
            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],sellConditions[2],sellConditions[3],sellConditions[4],sellConditions[5],sellConditions[6],
            "\n +-----------------------------   ",


            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+