//+------------------------------------------------------------------+
//|                                                 Y3_POWER_LIB.mqh |
//|                                               Y3 Trading Systems |
//|                                                     www.y3web.it |
//+------------------------------------------------------------------+
// per utilizzare questa libreria è necessario:
/*
0) il programma deve includere questo file con #include  <Y3_POWER_LIB.mqh>
1) lanciare initY3_POWER_LIB(nome_del_file_senza_estensione, magic_number_di_questo_EA, maPeriod);
2) OvertureBuy ed OvertureSell devono usare setPower(POWER) per settare il numero di lotti per ogni operazione
3) fermetureBuy e fermetureSell devono avere addOrderToHistory(ticketBuy o ticketSell) per registrare ogni ordine che viene fatto.
   è necessario gestire la chiusura di ordini con lotti differenti, quindi in fermetureBuy e fermetureSell è necessario aggiungere
         if (OrderSelect(ticketBuy o ticketSell,SELECT_BY_TICKET)==true)
         double lots = OrderLots();  
   ed usare lots al posto di POWER per chiudere l'ordine.
   
4) è possibile aggiungere questo alla commentaire per avere il numero di trades, il totale dei pips, e la dimensione del lotto attuale
            "\n TRADES           : ",ArraySize(historicPips),
            
            "\n CUMULATE PIPS    : ",historicPips[ArraySize(historicPips)-1],
            
            "\n POWER            : ",POWER,

            
Il sistema registra il profitto in pips di ogni ordine relativo a questo EA e questo simbolo, 
ne crea una media e "sospende" i trade quando la performance del programma scende sotto alla media stessa. 
La sospensione non è reale: i trade vengono fatti con 0.01 lotti in modo da tenere sempre traccia dei pips guadagnati o persi, ma annullando quasi le perdite monetarie.

*/

double historicPips[];
string HistoryFileName = "noName";
double macurrent = 0; //ma on historicPips
double newPower = 0;
int Y3_maPeriod = 5;
bool enableLibrary = true;


int initY3_POWER_LIB(string fileName, int magic, int maPeriod=5, bool enable=true){
   
   // set the name of the file
   HistoryFileName = fileName+Symbol()+".csv";
   
   //delete old file, if exists
   deleteFile(HistoryFileName);
   
   //initialize history
   initOrderHistory(magic);
   
   Y3_maPeriod = maPeriod;
   
   enableLibrary = enable;
   
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
   //calculate the moving averages on earned pips
   macurrent=iMAOnArray(historicPips,0,Y3_maPeriod,0,MODE_SMA,0);
   
   Print("addOrderToHistory - pips: ",historicPips[0], " - iMA: ",macurrent);
   
   ArraySetAsSeries(historicPips, false);

   //scrivo su un file i pips, la media e il numero di lotti per verificare con excel
   addToFile(HistoryFileName, ticket, k, pips, historicPips[k], macurrent, orderSize);


   return(0);


}
// ---------------------end--------------------------------+

// ---------------- SET POWER --------------------+
double setPower(double originalPower){

   //prepare the array as timeSeries
   ArraySetAsSeries(historicPips, true);
   
   //calculate the moving averages on earned pips
   macurrent=iMAOnArray(historicPips,0,Y3_maPeriod,0,MODE_SMA,0);
   
   Print("setPower - pips: ",historicPips[0], " - iMA: ",macurrent);
   
   if (historicPips[0] < macurrent) { // if performance goes under ema, limit the lot size to 0.01
      
      if (enableLibrary==true) //activate reduction only if library is enabled
         if ((nomIndice == "GER30") || (nomIndice == "FRA40") || (nomIndice == "XAUUSD") || (nomIndice == "USOil"))
            {newPower = 1;}
         else
            {newPower = 0.01;}
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
int addToFile(string fileName, string ticket, int k, int orderpips, int pips, double ma, double lots){
      
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
         FileWrite(file_handle,ticket,"k="+k,orderpips,pips,ma,lots);
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



