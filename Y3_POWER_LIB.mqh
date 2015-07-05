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

double historicPips[], historicPipsMA[], listOfPips[];
string HistoryFileName = "noName";
double macurrent = 0; //ma on historicPips
double newPower = 0;
int Y3_maPeriod = 3;
bool enableLibrary = true;
bool enableAdaptive = false;
int adaptive_maPeriod = 0; //portata fuori per poter stampare a schermo il suo valore


int initY3_POWER_LIB(string fileName, int magic, int maPeriod=3, bool enable=true, bool adaptive = false){
   
   // set the name of the file
   HistoryFileName = fileName+Symbol()+".csv";
   
   //delete old file, if exists
   deleteFile(HistoryFileName);
   
   Y3_maPeriod = maPeriod;
   
   enableLibrary = enable;
   
   //enable Adaptive maPeriod
   enableAdaptive = adaptive; Print("initY3_POWER_LIB: enableAdaptive = "+adaptive);

   //initialize history
   initOrderHistory(magic);
   
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
   
   double stDev = 0;
   
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
   
   //Print("addOrderToHistory: historicPips["+k+"]"+historicPips[k]);
   

   //prepare the array as timeSeries
   ArraySetAsSeries(historicPips, true);
   

   
   // ==============================
   // adaptive average system
   // ==============================

   // versione 2: Y3
   // pi� tempo passo sotto la media, pi� allungo la media. Al contrario, quando ci passo sopra, la accorcio per seguire il movimento pi� da vicino
   // per farlo mi serve lo storico delle medie, visto che vano calcolate con periodi diversi nel tempo. Per farlo ho creato un array historicPipsMA[]
   //k = ArraySize(historicPipsMA); //get array size
   ArrayResize(historicPipsMA,k+1,100000); //increment it by one to put in the new MA value
   
   // giro l'array per cercarci dentro come una timeseries
   ArraySetAsSeries(historicPipsMA, true);
   
   // cerco quante volte i pips sono stati sotto alla media negli ultimi n trades
   int underTheMA = 0; 
   adaptive_maPeriod = Y3_maPeriod; 


    // ====== Test con Deviazione Standard ============================
/*    
      ArrayResize(listOfPips,k+1,100000); // increment listOfPips, too
      listOfPips[k] = pips; //add last trade's pips to the list of pips
      ArraySetAsSeries(listOfPips, true);    


    // se i pips scendono sotto alla media di ieri...
    if (historicPips[0] < historicPipsMA[1]){
      
      // la deviazione standard � da sommare, perch� la media deve rimanere sopra
      stDev = MathAbs(iStdDevOnArray(listOfPips,k,k,0,MODE_EMA,0));
   
      Print("addOrderToHistory: Ord."+ticket+" - pips: k="+k+" -- historicPips[0] < historicPipsMA[1]  --- stDev="+stDev);
      
    }
    
    else{
      
      // la deviazione standard � da sottrarre, perch� la media deve rimanere sopra
      stDev = 0 - MathAbs(iStdDevOnArray(listOfPips,k,k,0,MODE_EMA,0));

      Print("addOrderToHistory: Ord."+ticket+" - pips: k="+k+" -- historicPips[0] >= historicPipsMA[1]  --- stDev="+stDev);
               
    }
    
    ArraySetAsSeries(listOfPips, false);
    

*/
    // ====== Fine Test con Deviazione Standard ============================
           
       

   for (int i=1; ((i<=11) && (i<=k)) ; i++){
      
      if (historicPips[i] <= historicPipsMA[i]) {

         
         // test calcolo media libreria GAU ver.6
/*        if (i <= 2) underTheMA += 1;
         if ((3 <= i) && (i <= 4)) underTheMA += 2;
         if ((5 <= i) && (i <= 6)) underTheMA += 3;
         if ((7 <= i) && (i <= 8)) underTheMA += 2;
         if ((9 <= i) && (i <= 10)) underTheMA += 1;

*/
         // ==== GAU EVOLUTA ==== ver.7
         if (i == 1) underTheMA += 1;
         if (i == 2) underTheMA += 2;
         if (i == 3) underTheMA += 4;
         if (i == 4) underTheMA += 6;
         if (i == 5) underTheMA += 8;
         if (i == 6) underTheMA += 10;
         if (i == 7) underTheMA += 8;
         if (i == 8) underTheMA += 6;
         if (i == 9) underTheMA += 4;
         if (i == 10) underTheMA += 2;
         if (i == 11) underTheMA += 1;
/*

         // ==== GAU EVOLUTA ==== ver.8
         if (i == 1) underTheMA += 1;
         if (i == 2) underTheMA += 3;
         if (i == 3) underTheMA += 6;
         if (i == 4) underTheMA += 9;
         if (i == 5) underTheMA += 6;
         if (i == 6) underTheMA += 3;
         if (i == 7) underTheMA += 1;



         // ==== GAU EVOLUTA ==== ver.9
         if (i == 1) underTheMA += 1;
         if (i == 2) underTheMA += 3;
         if (i == 3) underTheMA += 6;
         if (i == 4) underTheMA += 9;
         if (i == 5) underTheMA += 12;
         if (i == 6) underTheMA += 9;
         if (i == 7) underTheMA += 6;
         if (i == 8) underTheMA += 3;
         if (i == 9) underTheMA += 1;
*/
         
       }
         
       
   }  //for

   // agguingo al minimo, il valore variabile
   if (enableAdaptive == true) { 
      
      //uso underTheMA slo se � superiore al periodo minimo indicato in Y3_maPeriod
      if (underTheMA > Y3_maPeriod) adaptive_maPeriod = Y3_maPeriod + underTheMA; 

      
      //adaptive_maPeriod non pu� mai superare il massimo numero di valori disponibili, altrimenti sarebbe impossibile calcolare la media
      if (adaptive_maPeriod > k) adaptive_maPeriod = k;
      
      
      }
   
   // =============== end ===========
   
   //calculate the moving averages on earned pips
   macurrent=iMAOnArray(historicPips,0,adaptive_maPeriod,0,MODE_SMA,0);
   
   
   
   //maY3 ver.8
   macurrent = macurrent + stDev;
   
   
   
   
   //aggiungo il nuovo valore della media nell'array historicPipsMA
   historicPipsMA[0] = MathRound(macurrent);
   
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
   
   //Print("setPower - pips: ",historicPips[0], " - iMA: ",macurrent);
   
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
   ArraySetAsSeries(historicPipsMA, false);
   
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



// --------------- MA AUTOADATTIVA ---------------+
int getMaFilter(int maxMaValue){
   // guardo gli ultimi 5 trades e per ogni perdente sottraggo 5 al maxMaValue
   
   int i = 0;
   int sub = 0; //valore da sottrarre al periodo della MA, variabile o fisso
   int k = ArraySize(historicPips); //get array size
   int result = maxMaValue;
   
   // se non ho almeno 1 trade chiuso, esco restituendo maxMaValue
   if (k < 1) return result;
   
   //altrimenti se ne ho 6 o pi� uso 6. Se ne ho meno di 6 uso quelli che ho
   //me ne servono 6 per sapere il risultato del trade 5 che � uguale a 5-6
   if (k >= 8) k = 8;
   
   // giro l'array per prendere gli ultimi trades da 0 a 6
   ArraySetAsSeries(historicPips, true);
   
   
   // ora scorro i trades. Se sono perdenti sottraggo 5 al risultato (che sar� il periodo della media mobile)
   for (i=0; i<k; i++){
   
      // esco al penultimo se k > 5 
      if ( (k>7) && (i == k-2) ) break;
      
      //il valore da sottrarre dipende dalla posizione in cui si trova il trade perdente
      if (i == 0) sub = 1;
      if (i == 1) sub = 3;
      if (i == 2) sub = 5;
      if (i == 3) sub = 7;
      if (i == 4) sub = 5;
      if (i == 5) sub = 3;
      if (i == 6) sub = 1;
      
      // se i == k-1 e k == i+1 sono nell'ultimo trade disponibile, 
      // quindi devo usare il suo valore per sapere se era vincente o perdente
      if ((i==k-1) && (k == i+1)) 
         { if (historicPips[i] < 0) result = result - sub; }
      
      //altrimenti per saperlo devo sottrarlo al valore precedente
      else 
         {if (historicPips[i] - historicPips[i+1] < 0) result = result - sub; }
   
   }
   
   
   ArraySetAsSeries(historicPips, false);
   
   return result;
   
   
   

}
// ------------------end--------------------------+





