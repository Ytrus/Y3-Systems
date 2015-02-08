//+------------------------------------------------------------------+
//| v 0.1 beta                                                       |
//|                                              http://www.y3web.it |
//| DEFAULT: PER ORA NESSUNO                                         |
//+------------------------------------------------------------------+

// Ogni volta che il prezzo tocca la media mobile, con la barra precedente che non la toccava
// entro in direzione del movimento (quindi verso l'attraversamento della Media Mobile)
// uso SL e TP fissi, decisi in base al timeframe ed allo strumento. Forse userò ATR per dimensionarli
 


//--------Index name------+

string nomIndice = "EURUSD"; //sovrascritto dopo in init()
 

//--------number of lots to trade--------------+
extern int SIGNATURE = 0011000;
extern string COMMENT = "Y3_MA_QUANTUM_CROSS";
extern double POWER = 0.1;
extern int MAPERIOD = 30;
extern int SL_PIPS = 15;
extern int TP_PIPS = 30;
extern string nameOfHistoryFile = "Y3_QMAQC_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 3;
extern bool enablePowerLIB = false;


//+------------------------------------------------------------------+


//------------------------Declarations-------------------------------+

bool tradeBuy   = false;

bool entreeBuy  = false;

bool tradeSell  = false;

bool entreeSell = false;

int ticketBuy;
int ticketSell;

double p; //order size





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

   ouvertureSell();

   commentaire();

//----

   return(0);

  }

//+---------------------end-----------------------------+

 

//------------------------Subroutine parameters--------------------------+

int paramD1()

{ 

   double a, b ;   
   
   entreeBuy  = false;

   entreeSell = false;
   
   a = iMA(nomIndice,0,MAPERIOD,0,MODE_EMA,5,1);


//-----------------enter buy order---------------------------+

   // la barra di ieri è totalmente sotto
   
   // verifico che non ci siano ordini aperti in questa barra: non ne apro mai 2 nella stessa barra, per ora)
   
   
   //atr = iATR(nomIndice, 0, 100, 0);
   
   if((Open[0] < a) &&
      (MarketInfo(nomIndice,MODE_BID) > a) && 
      (chk_ordersOnThisBar(ticketBuy) == false) &&
      High[1] < a
     ) 
   {
         entreeBuy = true; 
         //Print("BUY - b:",b," - a:",a);
   }

   

//-----------------end---------------------------------------------+
 

//-----------------enter sell order----------------------------+



   if( (Open[0] > a) &&
      (MarketInfo(nomIndice,MODE_BID) < a) && 
      (chk_ordersOnThisBar(ticketSell) == false) &&
      Low[1] > a
     )    {
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

      stoploss   = MarketInfo(nomIndice,MODE_ASK) - SL_PIPS*Point;

      takeprofit = MarketInfo(nomIndice,MODE_ASK) + TP_PIPS*Point;

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
   

      
      stoploss   = MarketInfo(nomIndice,MODE_BID) + SL_PIPS*Point;
      
      takeprofit = MarketInfo(nomIndice,MODE_BID) - TP_PIPS*Point;

      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketSell = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,COMMENT ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Sell-----------------+

      if(ticketSell > 0) tradeSell = true;

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

            "\n OrdersTotal       : ",OrdersHistoryTotal(),

            "\n TICKET SELL      : ",ticketSell,
            
            "\n TRADES           : ",ArraySize(historicPips),
            
            "\n LAST TRADE PIPS  : ",historicPips[ArraySize(historicPips)-1],
            
            "\n POWER            : ",POWER,

            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+