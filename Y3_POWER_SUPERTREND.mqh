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


01/05/2015 =========================================
aggiunto sistema di adaptive MA Period.
Di default è disattivo per compatibilità con i vecchi EA che usano questa libreria.
Se attivo il periodo della ma dei pips guadagnati viene allungato se il sistema perde: più perde più si allunga.
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
   enableAdaptive = adaptive; //Print("initY3_POWER_LIB: enableAdaptive = "+adaptive);

   //initialize history
   initOrderHistory((string)magic);
   
   return(0);

}



int initOrderHistory(string s){



   // gli ordini nella history sono ordinati per data di apertura (o per orderticket?) e non per data di chiusura.
   // a me servono ordinati per data di chiusura, quindi li prendo e li metto in un array per ordinarli
   // poi uso questo array per estrarre gli ordini nell'ordine corretto

   // array con  OrderCloseTime() e OrderTicket()
   // la prima dimensione è la data di chiusura perchè si può usare solo quella per sortare l'array
   int orderList[][2]; // OrderCloseTime(), OrderTicket()
   
   // inserisco gli ordini di questo robot nell'array orderList
   for (int i=0; i<OrdersHistoryTotal(); i++) 
   {
      if ( (OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==true) && ((string)OrderMagicNumber()==s) && ((string)OrderSymbol()==nomIndice) )
      {
         
         //prendo la dimensione attuale dell'array
         int k = ArrayRange(orderList,0);
                  
         //aumento lo spazio nell'array di uno
         ArrayResize(orderList,k+1,100000);
         
         //metto i dati di questo ordine nell'array
         orderList[k][0] = OrderCloseTime();
         orderList[k][1] = OrderTicket();
         
         //Print("orderList: size:"+(string)k+", OrderCloseTime:"+ (string)orderList[k][0] +", OrderTicket:"+(string)orderList[k][1]);
         
      }
   
   }


   // poi ordino l'array orderList[],[] dall'ordine più vecchio a quello più recente
   if (ArrayRange(orderList,0) > 0) ArraySort(orderList,WHOLE_ARRAY,0,MODE_ASCEND);
   
   
   //inserisco gli ordini nella history
   for (int i=0; i<ArrayRange(orderList,0); i++) 
   {
      Print("Aggiunto un ordine all'array, i: ",i," ticket:",orderList[i][1] );  
      //aggiungo questo ordine alla history ed al file
      addOrderToHistory(orderList[i][1]);
      //Print("Aggiunto un ordine all'array, i: ",i );  
   }

   
   return(0);   
   
}


// --------------- add orders to history ----------------+
int addOrderToHistory(int ticket){
   // se non lo faccio per qualche motivo lui lo considera già girato. Il motivo non lo trovo. E' successo alla relase 0.3.2
   ArraySetAsSeries(historicPips, false);
   ArraySetAsSeries(historicPipsMA, false);
   
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

   if (k>0){
    historicPips[k] = historicPips[k-1]+pips;
   }
   else{
    historicPips[k] = pips;}
      

   //prepare the array as timeSeries
   ArraySetAsSeries(historicPips, true);

   
   // ==============================
   // adaptive average system
   // ==============================

   // versione 2: Y3
   // più tempo passo sotto la media, più allungo la media. Al contrario, quando ci passo sopra, la accorcio per seguire il movimento più da vicino
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
      
      // la deviazione standard è da sommare, perchè la media deve rimanere sopra
      stDev = MathAbs(iStdDevOnArray(listOfPips,k,k,0,MODE_EMA,0));
   
      Print("addOrderToHistory: Ord."+ticket+" - pips: k="+k+" -- historicPips[0] < historicPipsMA[1]  --- stDev="+stDev);
      
    }
    
    else{
      
      // la deviazione standard è da sottrarre, perchè la media deve rimanere sopra
      stDev = 0 - MathAbs(iStdDevOnArray(listOfPips,k,k,0,MODE_EMA,0));

      Print("addOrderToHistory: Ord."+ticket+" - pips: k="+k+" -- historicPips[0] >= historicPipsMA[1]  --- stDev="+stDev);
               
    }
    
    ArraySetAsSeries(listOfPips, false);
    

*/
    // ====== Fine Test con Deviazione Standard ============================
/*           
       

   for (int i=1; ((i<=11) && (i<=k)) ; i++){
      
      if (historicPips[i] <= historicPipsMA[i]) {

         
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
         
       }
         
       
   }  //for

   // agguingo al minimo, il valore variabile
   if (enableAdaptive == true) { 
      
      //uso underTheMA slo se è superiore al periodo minimo indicato in Y3_maPeriod
      // attenzione!!! in questo modo non sommo mai 1 o 2, 3 etc. Sommo minimo 6 solo quando underTheMA è almeno 6 (se Y3_maPeriod è 5)
      if (underTheMA > Y3_maPeriod) adaptive_maPeriod = Y3_maPeriod + underTheMA; 
      
      
      //adaptive_maPeriod non può mai superare il massimo numero di valori disponibili, altrimenti sarebbe impossibile calcolare la media
      if (adaptive_maPeriod > k) adaptive_maPeriod = k;
      
      
      }
*/   
   // =============== end ===========
   
   //calculate the moving averages on earned pips
   //macurrent=iMAOnArray(historicPips,0,adaptive_maPeriod,0,MODE_SMA,0); // media mobile con gaussiana sul periodo
   //macurrent=getAMA(historicPips, nFast); // AMA
   macurrent=getSupertrend(historicPips); // Supertrend
   
   
   //maY3 ver.8
   //macurrent = macurrent + stDev;
   
   
   
   
   //aggiungo il nuovo valore della media nell'array historicPipsMA
   historicPipsMA[0] = MathRound(macurrent);
   
   Print("addOrderToHistory - pips: ",historicPips[0], " - iMA: ",historicPipsMA[0]);
   
   ArraySetAsSeries(historicPips, false);
   ArraySetAsSeries(historicPipsMA, false);
   
   //scrivo su un file i pips, la media e il numero di lotti per verificare con excel
   addToFile(HistoryFileName, (string)ticket, k, pips, historicPips[k], macurrent, adaptive_maPeriod, orderSize );


   return(0);


}
// ---------------------end--------------------------------+

// ---------------- SET POWER --------------------+
double setPower(double originalPower, int LooseRatio, int WinRatio, double recStopper){

   // se la libreria è disattiva, restituisco la POWER originale
   if (enableLibrary==false) return originalPower;

   //set the arrays as normal arrays
   ArraySetAsSeries(historicPips, false);
   ArraySetAsSeries(historicPipsMA, false);

   
   //prepare the array as timeSeries
   ArraySetAsSeries(historicPips, true);
   ArraySetAsSeries(historicPipsMA, true);

   double minLot = MarketInfo(nomIndice,MODE_MINLOT);
   
   // se non ho dati nell'array historicPipsMA, restituisco minLot
   if (ArraySize(historicPipsMA) == 0) return(minLot);
  
   // se ho un numero do trades inferiore al numero di trade analizzati dall'AMA, restituisco minLot
   if (ArraySize(historicPipsMA) < 9) return(minLot);
  
   //get the moving averages on earned pips
   macurrent = historicPipsMA[0];
   
   
   //----------------------------------------------------+
   //  Recovery sulle posizioni
   //----------------------------------------------------+
   // calcolo le digits dei lotti dello strumento
   int lotDigits;
   
   if(minLot == 1)  lotDigits = 0;
   if(minLot == 0.1)  lotDigits = 1;
   if(minLot == 0.01)  lotDigits = 2;

   
   
   double step = 0;              // costante da sommare o sottrarre ad ogni iterazione
   double loosefactor = 0;       // fattore finale da sommare alla dimensione in caso di perdite precedenti
   double winfactor = 0;         // fattore finale da sottrarre alla dimensione in caso di perdite precedenti

   // calcolo lo step come percentuale della size originale
   double LooseStep = NormalizeDouble( (originalPower/100*LooseRatio), lotDigits);
   double WinStep = NormalizeDouble( (originalPower/100*WinRatio), lotDigits);
   
   
   
   // per ogni posizione consecutiva in perdita sommo LooseStep
   for (int x=0; (x<=ArraySize(historicPips)-2) && (x<=4); x++)
   {  
      if (historicPips[x]>historicPips[x+1]) break;                        // se la posizione era in guadagno, esco senza sommare nulla
      if (x==4) {loosefactor = 0; break;}
      if (historicPips[x]<historicPips[x+1])                               // altrimenti sommo step
      {
         
         
         loosefactor = loosefactor + LooseStep;
         
         // ---------------------------------------------------------+
         //   OPO - Open Orders
         // ---------------------------------------------------------+
         // se l'ultimo ordine CHIUSO era perdente, sommo step anche per ogni ordine aperto che ho in essere
         if(x==0)
         {
            for(int pos=0;pos<OrdersTotal();pos++)
            {
               if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
               if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderCloseTime() == 0) )
                  {
                     loosefactor = loosefactor + LooseStep; //versione che ignora profitto degli ordini aperti
                     
                     // test verifica se ordini aperti sono in guadagno o in perdita
                     //if (OrderProfit() > 0)
                     //   factor = factor - LooseStep;
                     //else
                     //   factor = factor + LooseStep;
                        
                  }
            }
         }
         

      }
   }


   // per ogni posizione consecutiva in guadagno sottraggo WinStep
   for (int x=0; (x<=ArraySize(historicPips)-2) && (x<=4); x++)
   {  
      if (historicPips[x]<historicPips[x+1]) break;                        // se la posizione era in perdita, esco senza sottrarre nulla
      if (historicPips[x]>historicPips[x+1])                               // altrimenti sottraggo step
      {

            winfactor = winfactor - WinStep;
         
         // ---------------------------------------------------------+
         //   OPO - Open Orders
         // ---------------------------------------------------------+        
         // se l'ultimo ordine CHIUSO era vincente, sottraggo step anche per ogni ordine aperto che ho in essere
         if(x==0)
         {
            for(int pos=0;pos<OrdersTotal();pos++)
            {
               if(OrderSelect(pos,SELECT_BY_POS)==false) continue;
               if ( (OrderMagicNumber() == SIGNATURE) && (OrderSymbol() == nomIndice) && (OrderCloseTime() == 0) )
                  {
                     winfactor = winfactor - WinStep; //versione che ignora profitto degli ordini aperti
                     
                     // test verifica se ordini aperti sono in guadagno o in perdita
                     //if (OrderProfit() > 0)
                     //   factor = factor - WinStep;
                     //else
                     //   factor = factor + WinStep;
                        
                  }
            }
         }
      }
   }   





   if (historicPips[0] < macurrent) // if performance goes under ema, limit the lot to min Lot Size
   { 

      //sotto alla lib riduco il potere del recovery
      newPower = minLot+ NormalizeDouble(recStopper*(loosefactor+winfactor),lotDigits);
      if (newPower <= 0) newPower = minLot;

   }
   else
   {
      newPower = originalPower+ loosefactor+winfactor;
      if (newPower <= 0) newPower = originalPower;
   }


   


   
   //rimetto a posto gli array
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
         FileWrite(file_handle,ticket,"k="+(string)k,orderpips,pips,MathRound(ma),maPeriod,lots);
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

   string logIt = "";




// --------------- MA AUTOADATTIVA ---------------+
int getMaFilter(int maxMaValue){
   // guardo gli ultimi n trades e per ogni perdente sottraggo 5 al maxMaValue
   
   if (enableAdaptive_AMA == false) return maxMaValue;  // Se non è attiva l'adattabilità del periodo dell'AMA, uso semplicemente il suo periodo base
   
   int i = 0;
   int sub = 0; //valore da sottrarre al periodo della MA, variabile o fisso
   int k = ArraySize(historicPips); //get array size
   int result = maxMaValue;
   
   //int n = maxMaValue-2; // sarebbe maxMaValue - 2(valore minimo ammissibile) +1(perchè me ne serve uno in più)
   int n = 11; // esclusiva per VER.6 , per tutte le altre usare quello sopra
   result = 0; // esclusiva per VER.6 , per tutte le altre eliminare questa riga
   
   // se non ho almeno 1 trade chiuso, esco restituendo maxMaValue
   if (k < 1)  return result;
   
   //altrimenti se ne ho n o più uso n. Se ne ho meno di 6 uso quelli che ho
   //me ne servono n per sapere il risultato del trade n-1 che è uguale a value(n-1)-value(n)
   if (k > n) k = n+1;
   
   // giro l'array per prendere gli ultimi trades da 0 a 6
   ArraySetAsSeries(historicPips, true);
   
   logIt = "=== ";
   
   // ora scorro i trades. Se sono perdenti sottraggo x al risultato (che sarà il periodo della media mobile)
   for (i=1; i<=k; i++){
   
   //logIt = logIt +"i="+ i +": k="+k+", n="+n+": ";
   
      // se supero n sono nel trade oltre a quello che mi serve: esco
      if (i>n)    break;

      // ================ VER. 1 - 5 fisso  ============================
      //sub = 5;
      // ================ VER. 2 - 5 fisso  ============================


      
      // ================ VER. 2 - GAUSSIANA  ============================
      /*
      if (i == 0) sub = 1;
      if (i == 1) sub = 3;
      if (i == 2) sub = 5;
      if (i == 3) sub = 7;
      if (i == 4) sub = 5;
      if (i == 5) sub = 3;
      if (i == 6) sub = 1;
      */
      // ================ VER. 2 - GAUSSIANA  ============================
 
      
      // ================ VER. 3 - AMA  ============================
      // La versione 3 non usa questa funzione ma una AMA già fatta (indicatoreCustom)
      // ================ VER. 3 - AMA  ============================
      


      // ================ VER. 4 - 1 fisso (n = 5)) ============================
      // Questa versione è fatta per pilotare il fastPeriod dell'ama e deve andare da 1 a 4
      // per ogni trade perdente sottraggo 1 al risultato
      // sub = 1;
      // ================ VER. 4 - 1 fisso  ============================

      
      // ================ VER. 5 - AMA  ============================
      // Questa versione permette semplicemente di impostare il massimo FastPeriod, come le altre, ma calcola da sola il numero di trade da controllare
      // in base alla formula numero max di trade da analizzare = maxMaPeriod - 2.
      // il codice che lo fa è nell'attribuzione del valore alla variabile n ad inizio funzione
      // lo scopo è quello di avere un valore opportuno per ogni grafico, perchè su alcuni funziona il 3(GER30)e su altri il 4, il 5 etc.
      // ================ VER. 5 - AMA  ============================
      
      
      
      // ================ VER. 6 - AMA con periodo gaussiano ============================
         if (i == 1) sub = 1;
         if (i == 2) sub = 2;
         if (i == 3) sub = 4;
         if (i == 4) sub = 6;
         if (i == 5) sub = 8;
         if (i == 6) sub = 10;
         if (i == 7) sub = 8;
         if (i == 8) sub = 6;
         if (i == 9) sub = 4;
         if (i == 10) sub = 2;
         if (i == 11) sub = 1;
      // ATTENZIONE: qui il valore ricevuto (maxValue) sarebbe in realtà minValue, ed ad ogni trade perdente SOMMO result invece di sottrarlo
      // quindi qui sotto uso righe diverse, fatte apposta per questa versione
      // ================ VER. 6 - AMA con periodo gaussiano ============================
      



      // =========== Versione esclusiva per VER. 6 =============================
      // se i == k sono nell'ultimo trade disponibile, il primo trade presente nello storico.
      // quindi devo usare il suo valore per sapere se era vincente o perdente
      if (i==k)
         { if (historicPips[i-1] < 0) result = result + sub; logIt = logIt + ""+(string)i+". "+ (string)result + " ||    ";}
      
      //altrimenti per saperlo devo sottrarlo al valore precedente
      else 
         {
            if (historicPips[i-1] - historicPips[i] < 0) { result = result + sub; }
            logIt = logIt + ""+ (string)i+". "+ (string)result + "  ||    ";
         }
      // ========== Versione esclusiva per VER. 6 ==============================
      
      
      
      
      /*
      // =========== Versione per tutte le altre =============================
      // se i == k sono nell'ultimo trade disponibile, il primo trade presente nello storico.
      // quindi devo usare il suo valore per sapere se era vincente o perdente
      if (i==k)
         { if (historicPips[i-1] < 0) result = result - sub; logIt = logIt + ""+i+". "+ historicPips[i-1] + " ||    ";}
      
      //altrimenti per saperlo devo sottrarlo al valore precedente
      else 
         {
            if (historicPips[i-1] - historicPips[i] < 0) { result = result - sub; }
            logIt = logIt + ""+ i+". "+ (historicPips[i-1] - historicPips[i]) + "  ||    ";
         }
      // ========== Versione per tutte le altre ==============================
      */
            
   }
   
   
   ArraySetAsSeries(historicPips, false);
   
   result = result + maxMaValue; //dersione esclusiva per VER.6 - per tutte le altre cancellare
   if (result < maxMaValue) result = maxMaValue;
   return result;
   

}
// ------------------end--------------------------+


//------------------------------------------------+
//   Calcolo dell'AMA da applicare alla libreria
//------------------------------------------------+

double getAMA(double inputArray[], int nfast = 2)
  {

   if (ArraySize(inputArray) == 0) {Print("******* AMA *******: Array vuoto!!"); return -1;}
   
   int       periodAMA = 9;
   int       nslow = 30;
   double    G = 2.0;
   double    dK = 2.0; 
   int       valueNumber = ArraySize(inputArray);
   
   //+------------------------------------------------------------------+
   
   int    cbars=0, prevbars=0, prevtime=0;
   
   double slowSC,fastSC;

    int    i, pos = 0;
    double noise = 0.000000001, AMA, AMA0, signal, ER;
    double dSC, ERSC, SSC;
    //----
    if (valueNumber > 40) valueNumber = 40;
    //----
    if(prevbars == valueNumber) 
        return(0);
    //---- TODO: add your code here
    slowSC = (2.0 / (nslow + 1));
    fastSC = (2.0 /(nfast + 1));
    cbars = 0;
    if(valueNumber <= (periodAMA + 2)) 
        return(0);
    //---- check for possible errors
    if(cbars < 0) 
        return(-1);
    //---- last counted bar will be recounted
    if(cbars > 0) 
        cbars--;
    pos = valueNumber - periodAMA - 2;
    AMA0 = inputArray[pos+1];
    while(pos >= 0)
      {
        if(pos == valueNumber - periodAMA - 2) 
            AMA0 = inputArray[pos+1];
        signal = MathAbs(inputArray[pos] - inputArray[pos+periodAMA]);
        noise = 0.000000001;
        for(i = 0; i < periodAMA; i++)
          {
            noise = noise + MathAbs(inputArray[pos+i] - inputArray[pos+i+1]);
          }
        ER = signal / noise;
        dSC = (fastSC - slowSC);
        ERSC = ER*dSC;
        SSC = ERSC + slowSC;
        AMA = AMA0 + (MathPow(SSC, G) * (inputArray[pos] - AMA0));
        //----
//        ddK = (AMA - AMA0);
/*
        if((MathAbs(ddK)) > (dK*Point) && (ddK > 0)) 
            kAMAupsig[pos] = AMA; 
        else 
            kAMAupsig[pos] = 0;
        if((MathAbs(ddK)) > (dK*Point) && (ddK < 0)) 
            kAMAdownsig[pos] = AMA; 
        else kAMAdownsig[pos] = 0; 
*/
        AMA0 = AMA;
        pos--;
      }
//----
    prevbars=valueNumber;
    return(AMA);
  }
// ------------------- end -----------------------+



//------------------------------------------------------+
//   Calcolo del Supertrend da applicare alla libreria
//------------------------------------------------------+
double getSupertrend(double inputArray[])
  {

   int i, limit;
   int shift = 0;    //scostamento dal minimo/massimo precedenti
   double result;
   double actualArray[];
//----       
   if (ArraySize(inputArray) < 3) return(0); // se non ho almeno 3 trade restituisco una linea che sopra ai trade (tenedo così la libreria chiusa)
   
   // Verifico su quanti trade posso calcolare la media delle ampiezze
   if (ArraySize(inputArray) < 11) 
      limit = ArraySize(inputArray)-2;
   else
      limit = 9;
   
   // calcolo l'ampiezza media dei trade   
   for (i=0; i<=limit; i++){
      shift += MathAbs(inputArray[i]-inputArray[i+1]);
   }
   if (shift > 0) shift = shift/10;
   
   // la libreria deve stare a due volte la deviazione standard
   shift = shift*STR_shift;



   if (historicPips[0] > historicPipsMA[1]){ // calcolo il nuovo valore, che sarà quello della linea inferiore
      result = historicPips[0] - shift;
      
      if ((result < historicPipsMA[1]) && (historicPips[1] > historicPipsMA[1])) result = historicPipsMA[1];
   }
   else{ // calcolo il nuovo valore, che sarà quello della linea superiore
      result = historicPips[0] + shift;
      
      if ((result > historicPipsMA[1]) && (historicPips[1] < historicPipsMA[1])) result = historicPipsMA[1];
   }


     
//----


   
   return(result);
  }



