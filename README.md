# mp4

MILEPÆL 4

Dette er markdown-dokumentet for milepæl 4 i DA-NAN3000. I dette dokumentet spesifiserers hva oppgaven går ut på, hva som er planen/krav, hvordan man bruker systemet og hva som er loggført.



## Oppgave
1. Klienten skal gi brukere samme funksjonalitet som det CGI-baserte web-grensesnittet fra funskjsjonskrav 4. i Milepæl 3.

Tips:

Hvis dere møter på problemer med "same origin policy", kan lønne seg å ta en ekstra titt i boka ( https://learning.oreilly.com/library/view/JavaScript:+The+Definitive+Guide,+7th+Edition/9781491952016/ch15.html#sameoriginpolicy ).

2. Filene som den består av, skal leveres av C-baserte tjeneren fra milepæl Milepæl 1 (Oppdatert [2021-02-01 ma.]) og Milepæl 2.

3. Ved bruk av nettleser som støtter Service workers, skal klienten sette opp en service worker som lagrer alle filene den trenger (HTML, js, css, etc.) og diktene (HTTP-reponsene) i en cache, slik at klientens lese-operasjonener kan fungere "offline" (altså frakoblet fra nettverkene).


## Plan

I denne oppgaven skal en Javascript klient bli skrevet som har så og si samme funksjonalitet som CGI-webgrensensittet fra MP3. Det vil si at den skal gjøre samme API-forespørsler ved utfylling og trykk av knapper.

HTML filen blir nesten identisk som HTML filen i MP3, men med unntaket av at i denne klienten er kun GET-metoder tillgjengelige hvis man ikke er logget inn. Javascript tillater å manipulere *DOM*-et(Document Object Module), altså det gjengitte grensensittet som tar utgangspunkt av den vedlagte HTML filen. Dette gjør at man kan legge til dynamiske elementer som senere kan bli fjernet.
Disse miljøene er definert som *pålogget* og *avlogget*-miljø.

Det er blitt personlig valgt å bruke moderne syntaks til Javascript klienten så deklarasjonstypene*let* og *const* er brukt istedet for *var*, og pilfunksjoner blir brukt istedetfor *function()*.

For å kunne gjøre forespøsler til REST-APIet må det legges til noen linjer i *conf/httpd.conf*-fila for å omgå *Same-Origin policy*. 
<pre>
		Header set Access-Control-Allow-Origin "http://localhost"
		Header set Access-Control-Allow-Headers "Accept, Content-Type"
		Header set Access-Control-Allow-Credentials "true"
		Header set Access-Control-Allow-Methods "GET, POST, PUT, DELETE"
</pre>
Selv om klienten kjører på samme vert(localhost), defineres Origin på både porter og protokoll. Derfor må dette gjøres da localhost:80 og localhost:8000 ikke er på samme Origin.



I tillegg er det satt opp en serive worker som tillater en bruker å gjøre alle GET-operasjoner offline, både å lese alle dikt på en gang og hvert enkelt dikt.



## Instruksjoner

Programmet krever følgende:

*	**mp3**-docker containere

Mesteparten av repositoriet består av MP2 så framgangen er ganske lik.
Kjør **run.sh** som rot.
<pre>
	sudo ./run.sh
</pre>

Gå så til *localhost/js-client/* i webleseren din


Her kan man teste alle knappene: logge inn, logge ut, hente ett dikt, hente alle dikt, lage dikt, endre dikt, slette dikt og slette alle dikt. I avlogget miljø kan man også hente dikt uten tilgang til nettet dersom man har først hentet alle diktene.


## Log

<pre>

22-04-2021
	MAGNUS: service workeren cacher nå hvert individuelle dikt

18-04-2021
	MAGNUS: Har så langt lagt evenlisteners til alle knappene som gir riktig forespørsel til REST APIet og gjør da samme utskrift til status-feltet som CGI-webgrensensittet i MP3. I tillegg blir cookies satt slik at sesjoner blir lagret og at man da forblir logget inn selvom man lukker siden og åpner den igjen.

	Jeg modifisert filen conf/httpd.conf på REST API docker containeren til å kunne sende respons til ikke-origin sendere.

		Header set Access-Control-Allow-Origin "http://localhost"
		Header set Access-Control-Allow-Headers "Accept, Content-Type"
		Header set Access-Control-Allow-Credentials "true"
		Header set Access-Control-Allow-Methods "GET, POST, PUT, DELETE"


	Dette kan i teorien bli satt i hvilken som helst blokk, men for sikkerhetskyld er det satt under *directory* blokken.
	Grunnen til dette er for å unngå Same-Origin policien. Det er ikke helt sikkert på hvorfor dette påvirker vårt system siden både REST APIet og webserveren kjører på samme Origin: localhost, men det kan være pga. at de kjører på forskjellige porter.

	For at webserverprogrammet skal kunne lese Javascript filer må en linje i etc/mime.types legges til: 

		text/javascript				js

	En liten endring jeg har gjort som er veldig bruktbart er at jeg har endred *webserver.c* koden til å laste inn *index.html* dersom en katalog er spesifisert i URLen.

	Det gjenstår da bare å få satt opp en service worker.

	OPPDATERING:
	Har fått lagt til service worker som funker greit fra det jeg har testa. Har også brukt mange timer på å finne ut hvorfor det ikke gikk ann å sende cookies. Kan hende det hadde noe med at cookien ble fornyet for hver gang jeg lastet inn siden på nytt, som viste seg å stamme fra at URLen som ble brukt for å sjekke loginstatus ikke var helt riktig. Den var *http://localhost/cgi-bin/rest.py/loginstatus* istedet for *http://localhost**:8000**/cgi-bin/rest.py/loginstatus*.
</pre>
