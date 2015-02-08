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

 


//--------Index name------+

string nomIndice = "EURUSD"; //sovrascritto dopo in init()
 

//--------number of lots to trade--------------+
extern int SIGNATURE = 0016000;
extern string COMMENT = "SYSTEM";
extern double POWER = 0.1;
extern int TP_Multiplier = 3;
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

   double a, b, plusDI, minusDI;   

   entreeBuy  = false;
   
   entreeSell = false;
   
   ArrayInitialize(buyConditions,false);   //Array buyConditions per debuggare
   ArrayInitialize(sellConditions,false);   //Array sellConditions per debuggare

   plusDI = iADX(nomIndice,0,14,PRICE_CLOSE,1,1);
   minusDI = iADX(nomIndice,0,14,PRICE_CLOSE,2,1);

   atr = iATR(nomIndice,0,100,1); //al momento uso un decomo di atr come massimo scostamento dal massimo(minimo) precedenti per sapere se entrare in un trade magari già chiuso poco fa.

//-----------------enter buy order---------------------------+

   a = iMA(nomIndice,0,21,0,MODE_EMA,PRICE_MEDIAN,0);
   b = iMA(nomIndice,0,100,0,MODE_EMA,PRICE_MEDIAN,0);
   
   if( a > b)                                      buyConditions[0] = true; // trend up
   if (chk_ordersOnThisBar(ticketBuy) == false)    buyConditions[1] = true; // non ho già inserito un ordine in questa barra
   if (Low[1] < Low[2])                            buyConditions[2] = true; // il minimo di ieri è inferiore a quello di ieri l'altro
   if (Close[0] > High[1])                         buyConditions[3] = true; // il prezzo attuale è superiore al massimo di ieri
   if (Close[0] < High[1] + (atr/10) )             buyConditions[4] = true; // non siamo troppo in alto
   if (plusDI > minusDI)                           buyConditions[5] = true; // ADX +DI > -DI
   //&&(High[1] < High[2]) // il massimo di ieri è inferiore al massimo di ieri l'altro
   //&&(High[0] < High[1]+10*Point) // non siamo oltre i 10 pips dal massimo di ieri
   
   if(
         (buyConditions[0]) 
      && (buyConditions[1])  
      && (buyConditions[2])  
      && (buyConditions[3])  
      && (buyConditions[4])  
      && (buyConditions[5])  
      //&& (buyConditions[6])  
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
   if (Close[0] < Low[1])                          sellConditions[3] = true; // il prezzo attuale è inferiore al minimo di ieri
   if (Close[0] > Low[1] - (atr/10))               sellConditions[4] = true; // Non siamo troppo in basso...
   if (plusDI < minusDI)                           sellConditions[5] = true; // ADX +DI < -DI
   //&&(Low[1] > Low[2])
   //&&(Low[0] > Low[1]-10*Point)
   
   
   if(
         (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2]) 
      && (sellConditions[3]) 
      && (sellConditions[4]) 
      && (sellConditions[5]) 
      //&& (sellConditions[6]) 
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
  

   if(entreeBuy == true)
   

   {

      stoploss   = (Low[1] - (SL_added_pips*Point));

      takeprofit = High[1] + ((High[1] - stoploss) * TP_Multiplier) ;

      stoploss   = NormalizeDouble(stoploss-1000*Point ,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketBuy = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Buy-----------------+

      if(ticketBuy > 0) tradeBuy = true;

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

  
   
   if(entreeSell == true)

   {
   

      
      stoploss   = (High[1] + (SL_added_pips*Point)) +100*Point;

      takeprofit = Low[1] - ((stoploss - Low[1]) * TP_Multiplier);
      
      stoploss   = NormalizeDouble(stoploss+1000*Point,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit-1000*Point,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketSell = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Sell-----------------+

      if(ticketSell > 0)tradeSell = true;

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
            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],buyConditions[2],buyConditions[3],buyConditions[4],buyConditions[5],
            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],sellConditions[2],sellConditions[3],sellConditions[4],sellConditions[5],
            "\n +-----------------------------   ",


            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+