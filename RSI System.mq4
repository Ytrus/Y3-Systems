//+------------------------------------------------------------------+
//| v 0.1 beta
//|                                        http://www.metaquotes.net |
//| DEFAULT: EURUSD M5                                               |
//+------------------------------------------------------------------+

// EURUSD M15: MAPERIOD:30 - RSIPERIOD: 16 - Y3_POWER_LIB_maPeriod: 4
// GBPGPY M15: MAPERIOD:38 - RSIPERIOD: 16 - Y3_POWER_LIB_maPeriod: 4

 


//--------Index name------+

string nomIndice = "EURUSD"; //sovrascritto dopo in init()
 

//--------number of lots to trade--------------+
extern int SIGNATURE = 1433314;
extern double POWER = 0.1;
extern int MAPERIOD = 30;
extern int RSIPERIOD = 16;
extern string nameOfHistoryFile = "RSI_System_HST_";
extern int Y3_POWER_LIB_maPeriod = 4;
extern bool enablePowerLIB = true;


//+------------------------------------------------------------------+


//------------------------Declarations-------------------------------+

bool tradeBuy   = false;

bool entreeBuy  = false;

bool sortieBuy  = false;

bool tradeSell  = false;

bool entreeSell = false;

bool sortieSell = false;

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
   
   //imposto il nome del file nella libreria Y3
   //HistoryFileName = nameOfHistoryFile;

   //cancello il file con la history
   //deleteFile(HistoryFileName);

   //inserisco nell'array della history e nel file i dati degli ordini chiusi per questo simbolo e questo magic number
   //initOrderHistory(SIGNATURE);
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

   fermetureBuy();

   ouvertureSell();

   fermetureSell();

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

   sortieBuy  = false;

   entreeSell = false;

   sortieSell = false;
   
   

//-----------------enter buy order---------------------------+

   a = iRSI(nomIndice,0,RSIPERIOD,PRICE_CLOSE,1);
   b = iRSI(nomIndice,0,RSIPERIOD,PRICE_CLOSE,2); 
   
   //atr = iATR(nomIndice, 0, 100, 0);
   
   if( b<30 && a>30) 
   {
         entreeBuy = true; 
         //Print("BUY - b:",b," - a:",a);
   }

   

//-----------------end---------------------------------------------+

 

//-----------------exit buy order---------------------------+

   
   if (OrderSelect(ticketBuy, SELECT_BY_TICKET)==true) // tentativo di protezione del profitto
   {
      int c = iBarShift(nomIndice, 0, OrderOpenTime()); //shift della barra in cui fu inserito l'ordine
      double h = High[iHighest(NULL,0,MODE_HIGH,b,1)]; // massimo valore visto da allora
      double maxProfit = h-OrderOpenPrice(); //massimo profitto visto sulla carta
      
      if (a<30) sortieBuy = true;// se rsi torna sotto a 30 è meglio uscire
      
      if (c>2)
      {      
         m = iMA(NULL,0,MAPERIOD,0,MODE_EMA,PRICE_CLOSE,1); //EMA a 14 barre di ieri. se passo oltre chiudo posizione
         if(MarketInfo(nomIndice,MODE_BID) < m && Close[1] > m) sortieBuy = true;// se ieri ero sopra a m ed oggi vi scendo sotto, chiudo
         //if (Open[1]>Close[1]) sortieBuy = true;
      }
      
      
      
  
      //if (maxProfit>3*atr && c>0)//se ho visto un profitto maggiore di tre volte atr....
      //{
      //   if(MarketInfo(nomIndice,MODE_BID)<=OrderOpenPrice()) sortieBuy = true;//brake even
      //}
      
      
      //if (maxProfit>=6*atr && c>0)//non permetto al sistema di perdere tutto. 
      //{
      //   if (MarketInfo(nomIndice,MODE_BID) <= OrderOpenPrice()+atr) sortieBuy = true;//Proteggo un profitto pari ad atr
      //}      
      
   }
   
     

//-----------------end---------------------------------------------+

 

//-----------------enter sell order----------------------------+



   if( b>70 && a<70 ) 
   {
      entreeSell = true; 
      //Print("SELL - b:",b," - a:",a);
   }
   

//-----------------end---------------------------------------------+

 

//-----------------exit sell order ---------------------------+

   
   if (OrderSelect(ticketSell, SELECT_BY_TICKET)==true) // tentativo di protezione del profitto
   {

      c = iBarShift(nomIndice, 0, OrderOpenTime()); //shift della barra in cui fu inserito l'ordine
      h = Low[iLowest(NULL,0,MODE_LOW,b,1)]; // minimo valore visto da allora
      maxProfit = OrderOpenPrice()-h; //massimo profitto visto sulla carta
      
      if (a>70) sortieSell = true;

   
      if (c>2)
      {
      m = iMA(NULL,0,MAPERIOD,0,MODE_EMA,PRICE_CLOSE,1); //EMA a 14 barre di ieri. se passo oltre chiudo posizione
      if(MarketInfo(nomIndice,MODE_BID) > m && Close[1] < m) sortieSell = true;// se ieri ero sotto a m ed oggivi salgo sopra, chiudo.
      //if (Open[1]<Close[1]) sortieSell = true;
      }


      
      
      //if (maxProfit>3*atr && c>0) //se ho visto un profitto maggiore di tre volte atr....
      //{
      //   if(MarketInfo(nomIndice,MODE_BID)>=OrderOpenPrice()) sortieSell = true;//brake even         
      //}
      

      //if (maxProfit>=6*atr && c>0)//non permetto al sistema di perdere tutto. 
      //{
      //   if (MarketInfo(nomIndice,MODE_BID) >= OrderOpenPrice()-atr) sortieSell = true;//Proteggo un profitto del 50%
      //}
   

   }

//-----------------end---------------------------------------------+

 

 

   return(0);

}

// +-----------------------end Subroutine parameters---------------------------------+

 

//------------------------------Buy open-----------------------+

int ouvertureBuy()

{

   double stoploss, takeprofit;
  

   if(tradeBuy == false && tradeSell == false && entreeBuy == true)
   

   {

      stoploss   = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);

      takeprofit = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);

      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketBuy = OrderSend(nomIndice,OP_BUY,setPower(POWER),MarketInfo(nomIndice,MODE_ASK),8,stoploss,takeprofit,"POWER" ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Buy-----------------+

      if(ticketBuy > 0) tradeBuy = true;

   }

   return(0);

}

//-----------------end----------------------------------------+

 

//-------------------Buy close-----------------------------------+

int fermetureBuy()

{

   bool t;

   if(tradeBuy == true && sortieBuy == true)

   {

   //------------------close ordre buy------------------------------------+
   if (OrderSelect(ticketBuy,SELECT_BY_TICKET)==true)
      double lots = OrderLots();     

   t = OrderClose(ticketBuy,lots,MarketInfo(nomIndice,MODE_BID),5,Brown);
   Print("fermetureBuy - ticketBuy ",ticketBuy);
   
  

   //-------------------confirmation du close buy--------------------------+

   if (t == true) { tradeBuy = false; addOrderToHistory(ticketBuy); ticketBuy = 0; }

   }

   return(0);

}

//-----------------end----------------------------------------+

 

//-----------------------------Sell open-----------------------+

int ouvertureSell()

{

   double stoploss, takeprofit;

  

   if(tradeSell == false && tradeBuy == false && entreeSell == true)

   {
   

      
      stoploss   = MarketInfo(nomIndice,MODE_ASK) + (MarketInfo(nomIndice,MODE_ASK) * 0.3);
      
      takeprofit = MarketInfo(nomIndice,MODE_ASK) - (MarketInfo(nomIndice,MODE_ASK) * 0.3);

      stoploss   = NormalizeDouble(stoploss,MarketInfo(nomIndice,MODE_DIGITS));

      takeprofit = NormalizeDouble(takeprofit,MarketInfo(nomIndice,MODE_DIGITS));

     

      ticketSell = OrderSend(nomIndice,OP_SELL,setPower(POWER),MarketInfo(nomIndice,MODE_BID),8,stoploss,takeprofit,"POWER" ,SIGNATURE,0,MediumBlue);

     

      //------------------confirmation du passage ordre Sell-----------------+

      if(ticketSell > 0)tradeSell = true;

   }

   return(0);

}

//-----------------end----------------------------------------+

 

//-------------------Sell close-----------------------------------+

int fermetureSell()

{

   bool t;

   if(tradeSell == true && sortieSell == true)

   {

   //------------------close ordre Sell------------------------------------+
   if (OrderSelect(ticketSell,SELECT_BY_TICKET)==true)
      double lots = OrderLots();     

   t = OrderClose(ticketSell,lots,MarketInfo(nomIndice,MODE_ASK),5,Brown);
   Print("fermetureSell - ticketSell ",ticketSell);  

   //-------------------confirmation du close Sell--------------------------+

   if (t == true){ tradeSell = false; addOrderToHistory(ticketSell); ticketSell = 0; }

   }

   return(0);

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

            "\n +--------------------------------------------------------+\n ");

   return(0);

   }

// +-----------------------FIN affichage ecran-------------------------+