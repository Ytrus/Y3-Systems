//+------------------------------------------------------------------+
//|                                                          AMA.mq4 |
//|                      Copyright © 2004, MetaQuotes Software Corp. |
//|                                        http://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2004, by konKop,wellx"
#property link      "http://www.metaquotes.net"
#property strict 

#property indicator_chart_window


//---- input parameters
extern int       maxLines = 4;
extern int       barLimit = 100;
extern int       minDistance = 14;

//---- buffers


//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
    for(int i=1; i<=maxLines; i++){
    ObjectCreate("S_"+i,OBJ_HLINE,0,0,0);
    ObjectCreate("R_"+i,OBJ_HLINE,0,0,0);
    ObjectSet("S_"+i,OBJPROP_COLOR,DeepSkyBlue);
    ObjectSet("S_"+i,OBJPROP_WIDTH,1);
    ObjectSet("S_"+i,OBJPROP_STYLE,STYLE_DASH);
    ObjectSet("S_"+i,OBJPROP_BACK,true);
    ObjectSet("R_"+i,OBJPROP_COLOR,OrangeRed);
    ObjectSet("R_"+i,OBJPROP_WIDTH,1);
    ObjectSet("R_"+i,OBJPROP_STYLE,STYLE_DASH);
    ObjectSet("R_"+i,OBJPROP_BACK,true);
    }
    return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
int deinit()
  {
    for(int i=1; i<=maxLines; i++){  
    ObjectDelete("S_"+i);
    ObjectDelete("R_"+i);
    }
    Comment("");
    return(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
  int start() 
    { 
     int limit = barLimit; 
     int shift = 0;
     int counted_bars=IndicatorCounted(); 
     int tollerance = (iATR(Symbol(),PERIOD_CURRENT,100,1)/Point)/2;
     double maxList[][4]; //numero di massimi e prezzo relativo: |importanza|prezzo|n°R|n°S|
     double minList[][4]; //numero di massimi e prezzo relativo
     double Resistance = 0; // prezzo della resistenza a cui tracciare la linea azzurra
     double Support = 0; // prezzo del supporto a cui tracciare la linea rossa
     double priceRef = 0;  // referenza durante le iterazioni per verificare quanti massimi o minimi trovo a questo prezzo
     int countedMax = 0;   // per sapere quanti maxValues ho trovato, perchè non coincidono col numero delle barre
     int countedMin = 0;   // e quanti minimi
     int tempCounted = 0;  // referenza interna per sapere se i massimi e minimi contati nell'iterazione sono maggiori
     int size = 0;
     bool done = false;    // per sapere se ho aggiunto un SR ad un valore esistente oppure no (e quindi ne devo aggiungere uno nuovo)
  //---- check for possible errors 
     if(counted_bars<0) return(-1); 
  //---- the last counted bar will be recounted 
     if(counted_bars>0) counted_bars--; 

  //---- main loop 
     for(int i=minDistance; i<limit; i++) 
       { 
        //---- RRRRRRRRRRRRRRRRRRRRRRRRRRRRRR ( MASSIMI )
        if ((High[i-1]<=High[i+2]) && (High[i]<=High[i+2]) && (High[i+1]<=High[i+2]) && (High[i+2]>=High[i+3]) && (High[i+2]>=High[i+4]) && (High[i+2]>=High[i+5]))
            {  
               // ho trovato un massimo, cerco nell'array se c'è già un valore simile:
               done = false;
               priceRef = NormalizeDouble(High[i+2],Digits); 
               size = ArraySize(maxList)/4; //la dimensione va divisa per il numero di dimensioni
               
               // traccio la freccia sopra a questo massimo
               drawArrow("DOWN",High[i+2], Time[i+2]);
               
               if(size == 0) 
                  {// aggiungo il primo valore
                     ArrayResize(maxList,size+1,1000); 
                     maxList[size,0] = 1;
                     maxList[size,1] = priceRef;
                     maxList[size,2] = 1; // numero di resistenze
                     maxList[size,3] = 0; // numero di supporti
                  }

               
               for (int x=0; x<size && size>0 ; x++)
               {  if( (maxList[x,1]>=priceRef-(tollerance*Point)) && (maxList[x,1]<=priceRef+(tollerance*Point)) ) 
                     { // c'è: aggiungo 1 al numero di occorrenze 
                        //Print("**** HIGH **** Barra "+i+" - Prezzo:"+priceRef+" - Valore Array: "+maxList[x,1]+" - forza: "+maxList[x,0]);
                        maxList[x,0]++; // + 1 al totale
                        maxList[x,2]++; // + 1 al numero di suporti
                        done = true;
                     }
               }
               
               // se non c'è, lo creao nuovo
               if(!done)   
                  {
                     ArrayResize(maxList,size+1,1000); 
                     maxList[size,0] = 1;
                     maxList[size,1] = priceRef;
                     maxList[size,2] = 1; // numero di resistenze
                     maxList[size,3] = 0; // numero di supporti
                  }
               
            
            }



        //---- SSSSSSSSSSSSSSSSSSSSSS MINIMI
        if ((Low[i-1]>=Low[i+2]) && (Low[i]>=Low[i+2]) && (Low[i+1]>=Low[i+2]) && (Low[i+2]<=Low[i+3]) && (Low[i+2]<=Low[i+4]) && (Low[i+2]<=Low[i+5]) )
            {  
               done = false;
               priceRef = NormalizeDouble(Low[i+2],Digits); 
               size = ArraySize(maxList)/4; //la dimensione va divisa per il numero di dimensioni

               // traccio la freccia sotto a questo minimo
               drawArrow("UP",Low[i+2], Time[i+2]);

               
               if(size == 0) 
                  {// aggiungo il primo valore
                     ArrayResize(maxList,size+1,1000); 
                     maxList[size,0] = 1;
                     maxList[size,1] = priceRef;
                     maxList[size,2] = 0; // numero di resistenze
                     maxList[size,3] = 1; // numero di supporti
                  }
                  
               // ho trovato un massimo, cerco nell'array se c'è già un valore simile:
               for (int x=0; x<size && size>0 ; x++)
               {  if( (maxList[x,1]>=priceRef-(tollerance*Point)) && (maxList[x,1]<=priceRef+(tollerance*Point)) ) 
                     { // c'è: aggiungo 1 al numero di occorrenze 
                        //Print("**** LOW **** Barra "+i+" - Prezzo:"+priceRef+" - Valore Array: "+minList[x,1]+" - forza: "+minList[x,0]);
                        maxList[x,0]++;  // +1 al totale
                        maxList[x,3]++;  // +1 al numero di supporti 
                        done = true;
                     }
               }
               
               // se non c'è, lo creao nuovo
               if(!done)   
                  {
                     ArrayResize(maxList,size+1,1000); 
                     maxList[size,0] = 1;
                     maxList[size,1] = priceRef;
                     maxList[size,2] = 0; // numero di resistenze
                     maxList[size,3] = 1; // numero di supporti
                  }            
            }
         
       } 



      string comment = "";
      int R_strength = 0;
      int S_strength = 0;
      int r = 1; // iteratore r
      int s = 1; // iteratore s
  
  
      // ==================================================================
      //     ORDINO L'ARRAY e prendo i 4 valori + importanti del momento
      // ==================================================================
      ArraySort(maxList,WHOLE_ARRAY,0,MODE_DESCEND);
      //ArraySort(minList,WHOLE_ARRAY,0,MODE_DESCEND);

      // nascondo le righe che non andrò a spostare
      for(int i=1;i<=maxLines;i++){
         ObjectMove("R_"+(string)(i+1),0,0,0);
         ObjectMove("S_"+(string)(i+1),0,0,0);
      }
      
     // scorro gli array per trovare i massimi e i minimi simili
     for (int i=0; i<ArraySize(maxList)/4; i++){
         
         if (i>maxLines) break;
         
         if (maxList[i,2]>=maxList[i,3])
         { ObjectMove("R_"+(string)(r),0,0,maxList[i,1]); ObjectSet("R_"+(string)(r),OBJPROP_WIDTH,maxList[i,0]); comment+="R: "+maxList[i,1]+" - importanza:"+maxList[i,0]+ " [R."+maxList[i,2]+"/S."+maxList[i,3]+"] \n"; r++;}
         else
         { ObjectMove("S_"+(string)(s),0,0,maxList[i,1]); ObjectSet("S_"+(string)(s),OBJPROP_WIDTH,maxList[i,0]); comment+="S: "+maxList[i,1]+" - importanza:"+maxList[i,0]+ " [R."+maxList[i,2]+"/S."+maxList[i,3]+"] \n"; s++; }
         
     }

/*
     // scorro gli array per trovare i massimi e i minimi simili
     for (int i=0; i<ArraySize(minList)/4; i++){
         comment+="S: "+minList[i,1]+" - importanza:"+minList[i,0]+ "\n";
         if (i>maxLines) break;
         //if (minList[i,0]>=3) 
         { ObjectMove("S_"+(string)(i+1),0,0,minList[i,1]); ObjectSet("S_"+(string)(i+1),OBJPROP_WIDTH,minList[i,0]);}
         
     }
*/     
     
     
     
     //---- COMMENT -----
     comment = "Tollerance:"+tollerance+"\n" + comment;
     comment = "Point:"+Point+"\n" + comment;
     
     Comment(comment);
     ArrayFree(maxList);

  //---- done 
     return(0); 
    }
//+------------------------------------------------------------------+




// ====================================
//      Disegno i punti di MAX e MIN
// ====================================

bool drawArrow(string dir, double p, datetime t){

   string objName = "A_"+(string)t; 
   int arrowCode = 233;       // default: Arrow UP
   color clr = DeepSkyBlue;       // default: up
   p=p-50*Point;              // default: up
   
   if (dir == "DOWN") { arrowCode = 234; clr = OrangeRed; p=p+240*Point;}
   
   
   
   if(ObjectFind(objName) < 0) { 
      Print("Oggetto non trovato "+objName);
      if(!ObjectCreate(objName,OBJ_ARROW,0,t,p)) { Print("Errore nella creazione di "+objName); return false; }
      
      ObjectSetInteger(0,objName,OBJPROP_ARROWCODE,arrowCode); ObjectSetInteger(0,objName,OBJPROP_COLOR,clr);
   }

   return false;

}