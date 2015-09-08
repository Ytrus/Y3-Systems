//+------------------------------------------------------------------+
//|                                                   WebRequest.mqh |
//|                                                             Ytre |
//|                                             https://www.y3web.it |
//+------------------------------------------------------------------+
#property copyright "Ytre"
#property link      "https://www.y3web.it"
#property strict
//+------------------------------------------------------------------+
//| Web Request functions                                                 |
//+------------------------------------------------------------------+

bool sendRequest(string destinationURL,string dataString)
   {
   
   
      int res; // risultato della chiamata WebRequest
      string header, responseHeader;
      char data[], responseData[];
      
      // imposto l'header da mandare alla pagina web
      header="Content-Type: Content-Type: application/x-www-form-urlencoded \r\n";
      
        
      // trasformo la stringa in un array char
      StringToCharArray(dataString,data,0,WHOLE_ARRAY,CP_UTF8);
      ArrayResize(data,ArraySize(data)-1);
   
      //invio la richiesta
      res=WebRequest("POST",destinationURL,header,0,data,responseData,responseHeader);
      
     
      //gestisco la risposta
      if (res == -1) // la chiamata non è stata fatta: forse si deve aggiungere l'indirizzo web a quelli consentiti
         {Alert("Attenzione: impossibile inviare i dati al server web. Aggiungere 'http://www.y3web.it/forexDataSaver.asp' ai consentiti"); return false;}
      else
      {
         
         // ---------------------------------------------------------------+
         // se la richiesta è stata fatta, verifico la risposta dal server |
         // ---------------------------------------------------------------+
         string responseBody = CharArrayToString(responseData,0,WHOLE_ARRAY,CP_UTF8);

         if (res == 200)
         {
                       
            // se la risposta del server contiene 'OK' la registrazione è andata a buon fine
            if (StringFind(responseBody,"OK",0) != -1 )
               {Print("Dati inviati al server web. Risposta: "+responseBody); return true;}
            
            //altrimenti il server ha risposto con l'errore incontrato (solitamente mancanza o incompatibilità dei dati
            else
               {Print("Dati inviati al server web con ERRORE. Risposta: "+responseBody); return false;}
          }

         else
            {Alert("Errore durante l'invio dei dati al server web. Risposta: "+responseBody); return false;}
      }
   }
