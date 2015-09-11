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

string webRequestBody; // variabile usata per contenere il messaggio da inviare al web server. Dichiarata qui così è disponibile in tutti i BOT includendo questo file
int webRequestAttempts = 0;

bool sendRequest(string destinationURL,string dataString, string PreMessage = "", int maxAttempts = 3)
   {
   
      // PreMessage     serve ad identificare chi ha chiamato la procedura dai log. Viene aggiunta ai messaggi stampati da sendRequest
      
      
      //---------------------------------------------------------+
      // per evitare centinaia di tentativi, in caso di errore   |
      //---------------------------------------------------------+
      if (webRequestAttempts >= maxAttempts) 
      {
         /* TODO:
         inserire qui il codice di invio email per segnalazione, se necessario; */ 
         return false;
      }
      
      int res; // risultato della chiamata WebRequest
      string header, responseHeader;
      char data[], responseData[];
      
      // imposto l'header da mandare alla pagina web
      header="Content-Type: application/x-www-form-urlencoded \r\n";
      
        
      // trasformo la stringa in un array char
      StringToCharArray(dataString,data,0,WHOLE_ARRAY,CP_UTF8);
      ArrayResize(data,ArraySize(data)-1);
   
      //invio la richiesta
      res=WebRequest("POST",destinationURL,header,0,data,responseData,responseHeader);
      
     
      //gestisco la risposta
      if (res == -1) // la chiamata non è stata fatta: forse si deve aggiungere l'indirizzo web a quelli consentiti
         {Alert(PreMessage+" - Attenzione: impossibile inviare i dati al server web. Aggiungere "+ destinationURL +" ai consentiti"); return false;}
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
               {Print(PreMessage+" - Dati inviati al server web. Risposta: "+responseBody); webRequestAttempts = 0; return true;}
            
            //altrimenti il server ha risposto con l'errore incontrato (solitamente mancanza o incompatibilità dei dati
            else
               {Print(PreMessage+" - Dati inviati al server web con ERRORE. Risposta: "+responseBody); webRequestAttempts+=1; return false;}
          }

         else
            {Alert(PreMessage+" - Errore durante l'invio dei dati al server web. Risposta: "+responseBody); webRequestAttempts+=1; return false;}
      }
   }
