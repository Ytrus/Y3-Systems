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

//bool sortieBuy  = false;

bool tradeSell  = false;

bool entreeSell = false;

//bool sortieSell = false;

int ticketBuy;

int ticketSell;

double p; //order size

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

   double a, b, m ;   

   entreeBuy  = false;
   
   entreeSell = false;
   
   ArrayInitialize(buyConditions,false);   //Array buyConditions per debuggare
   ArrayInitialize(sellConditions,false);   //Array sellConditions per debuggare



//-----------------enter buy order---------------------------+

   a = iMA(nomIndice,0,21,0,MODE_EMA,PRICE_MEDIAN,0);
   b = iMA(nomIndice,0,100,0,MODE_EMA,PRICE_MEDIAN,0);
   
   if( a > b)                                      buyConditions[0] = true; // trend up
   if (chk_ordersOnThisBar(ticketBuy) == false)    buyConditions[1] = true; // non ho già inserito un ordine in questa barra
   if (Low[1] < Low[2])                            buyConditions[2] = true; // il minimo di ieri è inferiore a quello di ieri l'altro
   if (Close[0] > High[1])                         buyConditions[3] = true; // il prezzo attuale è superiore al massimo di ieri
   //&&(High[1] < High[2]) // il massimo di ieri è inferiore al massimo di ieri l'altro
   //&&(High[0] < High[1]+10*Point) // non siamo oltre i 10 pips dal massimo di ieri
   
   if(
         (buyConditions[0]) 
      && (buyConditions[1])  
      && (buyConditions[2])  
      && (buyConditions[3])  
      //&& (buyConditions[4])  
      //&& (buyConditions[5])  
      //&& (buyConditions[6])  
      )
   {
         entreeBuy = true; 
         //Print("BUY - b:",b," - a:",a);
   }

   

//-----------------end---------------------------------------------+
 

//-----------------enter sell order----------------------------+



   if ( a < b)                                     sellConditions[0] = true; // trend down
   if (chk_ordersOnThisBar(ticketSell) == false)   sellConditions[1] = true; // non ho già inserito un ordine in questa barra
   if (High[1] > High[2])                          sellConditions[2] = true; // il massimo di ieri è superiore al massimo di ieri l'altro
   if (Close[0] < Low[1])                          sellConditions[3] = true; // il prezzo attuale è inferiore al minimo di ieri
   //&&(Low[1] > Low[2])
   //&&(Low[0] > Low[1]-10*Point)
   
   
   if(
         (sellConditions[0])  
      && (sellConditions[1]) 
      && (sellConditions[2]) 
      && (sellConditions[3]) 
      //&& (sellConditions[4]) 
      //&& (sellConditions[5]) 
      //&& (sellConditions[6]) 
   )

   {
      entreeSell = true; 
      //Print("SELL - b:",b," - a:",a);
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

      takeprofit = High[1] + ((High[1] - stoploss) * TP_Multiplier);

      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketBuy = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Buy-----------------+

      if(ticketBuy > 0) tradeBuy = true;

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
   

      
      stoploss   = (High[1] + (SL_added_pips*Point));

      takeprofit = Low[1] - ((stoploss - Low[1]) * TP_Multiplier);
      
      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketSell = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Sell-----------------+

      if(ticketSell > 0)tradeSell = true;

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
            "\n BUY Conditions   : ",buyConditions[0],buyConditions[1],buyConditions[2],buyConditions[3],
            "\n SELL Conditions  : ",sellConditions[0],sellConditions[1],sellConditions[2],sellConditions[3],
            "\n +-----------------------------   ",


            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+