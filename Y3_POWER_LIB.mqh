//+------------------------------------------------------------------+
//|                                                 Y3_POWER_LIB.mqh |
//|                                               Y3 Trading Systems |
//|                                                     www.y3web.it |
//+------------------------------------------------------------------+
// per utilizzare questa libreria � necessario:
/*
0) il programma deve includere questo file con #include  <Y3_POWER_LIB.mqh>
1) lanciare initY3_POWER_LIB(nome_del_file_senza_estensione, magic_number_di_questo_EA, maPeriod);
2) OvertureBuy ed OvertureSell devono usare setPower(POWER) per settare il numero di lotti per ogni operazione
3) fermetureBuy e fermetureSell devono avere addOrderToHistory(ticketBuy o ticketSell) per registrare ogni ordine che viene fatto.
   � necessario gestire la chiusura di ordini con lotti differenti, quindi in fermetureBuy e fermetureSell � necessario aggiungere
         if (OrderSelect(ticketBuy o ticketSell,SELECT_BY_TICKET)==true)
         double lots = OrderLots();  
   ed usare lots al posto di POWER per chiudere l'ordine.
   
4) � possibile aggiungere questo alla commentaire per avere il numero di trades, il totale dei pips, e la dimensione del lotto attuale
            "\n TRADES           : ",ArraySize(historicPips),
            
            "\n CUMULATE PIPS    : ",historicPips[ArraySize(historicPips)-1],
            
            "\n POWER            : ",POWER,

            
Il sistema registra il profitto in pips di ogni ordine relativo a questo EA e questo simbolo, 
ne crea una media e "sospende" i trade quando la performance del programma scende sotto alla media stessa. 
La sospensione non � reale: i trade vengono fatti con 0.01 lotti in modo da tenere sempre traccia dei pips guadagnati o persi, ma annullando quasi le perdite monetarie.


01/05/2015 =========================================
aggiunto sistema di adaptive MA Period.
Di default � disattivo per compatibilit� con i vecchi EA che usano questa libreria.
Se attivo il periodo della ma dei pips guadagnati viene allungato se il sistema perde: pi� perde pi� si allunga.
Ad oggi i vantaggi non sono chiari: le preformance sono meglio con un ma=5 (sul bot HA), ma questo sistema sembra adattarsi bene ai cambiamenti del mercato, e lo fa da solo
Se si attiva Adaptive, il valore indicato come Y3_maPeriod diventa il minimo periodo possibile. Il sistema lo allunga al bisogno, ma non lo accorcia oltre a quello.
*/

double historicPips[], historicPipsMA[];
string HistoryFileName = "noName";
double macurrent = 0; //ma on historicPips
double newPower = 0;
int Y3_maPeriod = 3;
bool enableLibrary = true;
bool enableAdaptive = false;


int initY3_POWER_LIB(string fileName, int magic, int maPeriod=3, bool enable=true, bool adaptive = false){
   
   // set the name of the file
   HistoryFileName = fileName+Symbol()+".csv";
   
   //delete old file, if exists
   deleteFile(HistoryFileName);
   
   Y3_maPeriod = maPeriod;
   
   enableLibrary = enable;
   
   //initialize history
   initOrderHistory(magic);
   
   //enable Adaptive maPeriod
   enableAdaptive = adaptive;

   
   return(0);

}



int initOrderHistory(string s){

   Print("Ordini presenti nella history: ",OrdersHistoryTotal());
   for (int i=0;i<ArraySize(historicPips);i++)
      {Print("Value in historicPips array ["+i+"]: "+historicPips[i]);}
   
   //loop history and get orders of this robot
   for (i=0; i<OrdersHistoryTotal(); i++) 
   {
      if ( (OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true) && (OrderMagicNumber()==s) && (OrderSymbol()==nomIndice) )
      {
         //aggiungo questo ordine all'array ed al file
         addOrderToHistory(OrderTicket());
         //Print("Aggiunto un ordine all'array, ticket: ",OrderTicket() );
      }
   
   }
   return(0);   
   
}


// --------------- add orders to history ----------------+
int addOrderToHistory(int ticket){

   int k = ArraySize(historicPips); //get array size
   //Print("addOrderToHistory - Array size: "+k);
   ArrayResize(historicPips,k+1,100000); //increment it by one to put in the new profit or loss in pips

   double orderSize;
   
   int pips;
   if(OrderSelect(ticket, SELECT_BY_TICKET)==true)
    {

      
        if(OrderType() == 0) //buy
         {pips = (OrderClosePrice() - OrderOpenPrice()) / Point;}
        
        if(OrderType() == 1) //sell
         {pips = ( OrderOpenPrice() - OrderClosePrice()) / Point;}
         
         orderSize = OrderLots();
    }
   else
      {Print("addOrderToHistory Error: ",GetLastError());}

   
   historicPips[k] = historicPips[k-1]+pips;
   

   //prepare the array as timeSeries
   ArraySetAsSeries(historicPips, true);
   
   
   // ==============================
   // test adaptive average system
   // ==============================

   // versione 2: Y3
   // pi� tempo passo sotto la media, pi� allungo la media. Al contrario, quando ci passo sopra, la accorcio per seguire il movimento pi� da vicino
   // per farlo mi serve lo storico delle medie, visto che vano calcolate con periodi diversi nel tempo. Per farlo ho creato un array historicPipsMA[]
   k = ArraySize(historicPipsMA); //get array size
   ArrayResize(historicPipsMA,k+1,100000); //increment it by one to put in the new MA value
   
   // giro l'array per cercarci dentro come una timeseries
   ArraySetAsSeries(historicPipsMA, true);
   
   // cerco quante volte i pips sono stati sotto alla media negli ultimi n trades
   int underTheMA = 0;
   int adaptive_maPeriod = Y3_maPeriod;
   for (int i=0; ((i<=10) && (i<k)) ; i++){
      if (historicPips[i] <= historicPipsMA[i]) 
         underTheMA = underTheMA + 2;
   }
   // agguingo al minimo, il valore variabile
   if (enableAdaptive == true) {adaptive_maPeriod = Y3_maPeriod + underTheMA; Print("addOrderToHistory() - Adaptive maPeriod ATTIVO");}
   
   // =============== end ===========
   
   //calculate the moving averages on earned pips
   macurrent=iMAOnArray(historicPips,0,adaptive_maPeriod,0,MODE_SMA,0);

   
   //aggiungo il nuovo valore della media nell'array historicPipsMA
   historicPipsMA[0] = macurrent;
   
   Print("addOrderToHistory - pips: ",historicPips[0], " - iMA: ",historicPipsMA[0]);
   
   ArraySetAsSeries(historicPips, false);
   ArraySetAsSeries(historicPipsMA, false);
   
   //scrivo su un file i pips, la media e il numero di lotti per verificare con excel
   addToFile(HistoryFileName, ticket, k, pips, historicPips[k], macurrent, adaptive_maPeriod, orderSize );


   return(0);


}
// ---------------------end--------------------------------+

// ---------------- SET POWER --------------------+
double setPower(double originalPower){

   //prepare the array as timeSeries
   ArraySetAsSeries(historicPips, true);
   ArraySetAsSeries(historicPipsMA, true);

   
   //calculate the moving averages on earned pips
   macurrent = historicPipsMA[0]; //macurrent=iMAOnArray(historicPips,0,adaptive_maPeriod,0,MODE_SMA,0);
   
   Print("setPower - pips: ",historicPips[0], " - iMA: ",macurrent);
   
   if (historicPips[0] < macurrent) { // if performance goes under ema, limit the lot size to 0.01
      
      if (enableLibrary==true) {//activate reduction only if library is enabled
         
         double minLot = MarketInfo(nomIndice,MODE_MINLOT);
         
         newPower = minLot;

         }
      else
         newPower = originalPower;
   }
   else
      newPower = originalPower;

   ArraySetAsSeries(historicPips, false);
   
   return(newPower);

}

// ------------------end--------------------------+


// -------------- write data to file -------------+
int addToFile(string fileName, string ticket, int k, int orderpips, int pips, double ma, int maPeriod, double lots){
      
   //se il file non esiste, lo creo
   int file_handle=FileOpen(fileName,FILE_READ|FILE_WRITE|FILE_CSV);
   if(file_handle!=INVALID_HANDLE)
     {
      PrintFormat("%s file is available for writing",fileName);
      PrintFormat("File path: %s",TerminalInfoString(TERMINAL_DATA_PATH));

      //-- get the end of the file to add last data to it
      if (FileSeek(file_handle,0,SEEK_END)==true)
      {
         //--- write values to the file
         FileWrite(file_handle,ticket,"k="+k,orderpips,pips,MathRound(ma),maPeriod,lots);
         PrintFormat("Data is written, %s file is closed",fileName);
      }
      //--- close the file
      FileClose(file_handle);

     }
   else
      PrintFormat("Failed to open %s file, Error code = %d",fileName,GetLastError());   
   
   return(0);
}
// ------------------end--------------------------+


// --------------------- DELETE FILE (ON INIT) --------------------+
int deleteFile(string fileName)
{

   if (FileDelete(fileName)==true) 
      Print("File ",fileName," deleted");
   else
      Print("File ",fileName," not present or protected");

   return(0);
}



// ------------------end--------------------------+


