# Mp3
Del 3 av prosjekt

## Oppgave
Sett opp et REST-api mot en sqlite-database og en editor som kan utføre følgende handlinger mot rest-apiet:
- Logge inn og ut bruker
- Hente alle dikt
- Hente et enkelt dikt
- Slette et enkelt dikt
- Slette alle brukerens dikt
- Endre et dikt
- Legge til et dikt

Editor og REST-api skal kjøre i to forskjellige docker-containere som er på samme nettverk. Disse to containerne skal ha visse begrensninger (namespaces, cgroups og capabilities). Statiske filer til editoren skal hentes fra MP2-serveren, som ligger på vertsnettverket. Alt skal kunne kjøres i nettleser/klient i samme nettverk som MP2-serveren.

## Generelt om oppsett og utførelse
Oppsettet består av følgende deler:

### Nettverk 1:
    Server fra Mp2
    Klient på vertsmaskin (nettleser for å vise editor)

### Nettverk 2: Docker-nettverk
    g7alpine1: Webservice (basert på docker-image g7alpineimage)
        - har filen cgi-bin/rest.py som tilbyr rest-api mot sqlite-database
        - Kjøres på port 8000:80

    g7alpine2: Webgrensesnitt (basert på docker-image g7mp3_image)
        - har filen cgi-bin/editor.sh som er et webgrensesnitt som kommuniserer med rest-apiet
        - Kjøres på port 8080:80

## REST api
- Rest-apiet kjører i containeren g7alpine1, der filen /cgi-bin/rest.py (skal oversettes til .sh) leverer data fra db1 (sqlite-database) som er satt opp i henhold til mp3-oppskriften for databasen. RESTapiet tar imot kall og sjekker REQUEST-METHOD, PATH og inn-data, og leverer respons basert på dette. Herunder følger kall og respons:

#### Hente alle dikt:
    url: /localhost:8000/cgi-bin/rest.py/diktsamling/dikt/
    method: get
    data: ""
    header: Content-Type: application/xml, Accept:application/xml
    respons: xml med alle dikt
    <diktsamling><dikt><diktID></diktID><dikt></dikt><epostadresse></epostadresse></dikt></diktsamling>

#### Hente et enkelt dikt:
    url: /localhost:8000/cgi-bin/rest.py/diktsamling/dikt/id
    method: get
    data: ""
    header: Content-Type: application/xml, Accept:application/xml
    respons: xml med et enkelt dikt
    <diktsamling><dikt><diktID></diktID><dikt></dikt><epostadresse></epostadresse></dikt></diktsamling>

#### Slette et enkelt dikt:
    url: /localhost:8000/cgi-bin/rest.py/diktsamling/dikt/id
    method: delete
    data: ""
    header: Content-Type: application/xml, Accept:application/xml
    respons: <result><status></status><statustext><statustext><data></data></result>

#### Slette alle dikt for innlogget bruker:
    url: /localhost:8000/cgi-bin/rest.py/diktsamling/dikt/
    method: delete
    data: ""
    header: Content-Type: application/xml, Accept:application/xml
    respons: <result><status></status><statustext><statustext><data></data></result>

#### Opprette nytt dikt:
    url: /localhost:8000/cgi-bin/rest.py/diktsamling/dikt/
    method: post
    data: "<dikt><text></text></dikt>"
    header: Content-Type: application/xml, Accept:application/xml
    cookie: user_session=sessionkey (må hentes ved login)
    respons: <result><status></status><statustext><statustext><data></data></result>

#### Endre dikt:
    url: /localhost:8000/cgi-bin/rest.py/diktsamling/dikt/id
    method: put
    data: "<dikt><text></text></dikt>"
    header: Content-Type: application/xml, Accept:application/xml
    cookie: user_session=sessionkey (må hentes ved login)
    respons: <result><status></status><statustext><statustext><data></data></result>

#### Login:
    url: /localhost:8000/cgi-bin/rest.py/login
    method: post
    data: <user><username></username><password></password></user>
    header: Content-Type: application/xml, Accept:application/xml
    respons: <result><status></status><statustext><statustext><sessionid></sessionid><data></data></result>

#### Logout:
    url: /localhost:8000/cgi-bin/rest.py/logout
    method: post
    data: <user><sessionid></sessionid></user>
    header: Content-Type: application/xml, Accept:application/xml
    respons: <result><status></status><statustext><statustext><sessionid></sessionid><data></data></result>

    Denne kan måtte endres noe, da session-id bør sendes i cookie

#### Sjekke login-status:
    url: /localhost:8000/cgi-bin/rest.py/loginstatus
    method: post
    data: <check><sessionid></sessionid></check>
    header: Content-Type: application/xml, Accept:application/xml
    respons: <result><status></status><statustext><statustext><sessionid></sessionid><user></user><data></data></result>

    Denne kan måtte endres noe, da session-id bør sendes i cookie


## Webgrensesnitt
- Grensesnittet ligger i fila /cgi-bin/editor.sh. Når denne kjøres vises først et grensesnitt med det man kan gjøre. Når man utfører en handling vil scriptet kalle seg selv med input-data, og utføre kall mot RESTapiet, som returnerer respons i nettleseren.

## Installering og oppsett for å kjøre
- Installer docker på maskinen hvis det ikke er gjort allerede
- Logg inn med din docker-id
- Last ned docker-image for mp3: hkulterud/dockerhub:g7mp3_image
    - $sudo docker run -d --cap-drop=setfcap --cpu-shares 512 -m 512m -it -p 8080:80 --name g7alpine2 hkulterud/dockerhub:g7mp3_image
    - Dette kallet vil opprette container med navn "g7alpine2", lytter på port 8080 på vert (rutes til port 80 i container), dropper setfcap-capability (krav i mp3). Her begrenses også minne-bruk til 512MB og 512 cpu-shares (capabilities-krav i mp3). CPU-share er en relativ verdi. Hvis totalt antall shares er 2048, vil 512 cpu-shares gi 50% tid av cpu.
- Opprette 2 containere basert på docker-image og sette opp porter
- Sette begrensninger på docker-containerne
- Kjøre igang mp2-serveren
- Starte containerne
- Kjøre http://172.17.0.2:8080/cgi-bin/editor.sh (g7alpine2-container) i nettleser

    For å sjekke ip-adresser på containerne:
    $sudo docker network inspect bridge | jq '.[] | {Containers}'

    Fullstending detaljert oppskrift og kommandoer som skal kjøres

## Merknader
### CGROUPS
    Vi setter begrensning på minnebruk slik:
    $sudo docker -m 500m --memory-swap -1 g7alpine1 (setter grense på 500MB)
    
    Sette antall cpu-shares for container:
    $sudo docker --cpu-shares 512 --memory-swap -1 g7alpine1 (setter grense på 500MB)
    
    Sjekk stats med følgende kommando for å se ressursbruk:
    $sudo docker stats --no-stream

### CAPABILITIES

    KJØRING AV CONTAINER MED CAP_DROP:
    docker run -d --cap-drop=setfcap -m 512m -it -p 8080:80 --name g7alpine2 hkulterud/dockerhub:g7mp3_image

    Her kan tilgjengelige egenskaper fjernes og legges til, slik at man inni containeren får mer eller mindre funksjonalitet. Dette kan sjekkes med følgende kommandoer:

    sudo docker inspect --format='{{.HostConfig.CapAdd}}' g7alpine1

    sudo docker inspect --format='{{.HostConfig.CapDrop}}' g7alpine1

    For å legge til eller fjerne: Kan bare gjøres når man oppretter containeren, ikke senere.

    Tillegg: kan også default fjerne følgende: audit_write

### NAMESPACES
    
    STOP DOCKER
    sudo systemctl stop docker

    LAG BRUKER dockremapper:
    sudo adduser dockremapper
    
    REMAP BRUKER - Start med namespaces tilgjengelig
    sudo dockerd --userns-remap=default &
    
    Dette starter docker med dockermap user og group opprettes og mappes mot ikke-priviligerte uid og gid - "ranges" i /etc/subuid og /etc/subgid - filene.

    Sjekk at bruker-navnerommet er riktig:
    $docker info
    
    Docker Root Dir: /var/lib/docker/165536.165536 (eksempel) viser at det kjøres i et eget navnerom. Det vanlige root-dir er: Docker Root Dir: /var/lib/docker
    
    ---- Teori ----
    
    For å gi root-brukeren i containeren mindre tilgang til vertssystemet/host, kan man mappe root i containeren til en annen bruker enn root i vertssystemet. Da vil root i containeren ikke ha tilgang til vertssystemet hvis noen skulle ta kontroll over brukeren i containeren.

    Før du setter opp namespaces, for å forstå:

    Sjekk at docker kjører som root:
    $sudo ps aux | grep dockerd

    Docker kjører default som root når man oppretter nye containere.

    Finn din id med følgende kommando: $id

    Kjør deretter container med følgende kommando:
    $sudo docker run --rm --user 1000:1000 alpine id
    der 1000 her er din brukers UID og GID

    Responsen uid=1000 gid=1000 viser at du nå kjører med gjeldende bruker, og ikke root. Men mange ganger trenger man å kjøre med root, uten tilgang til vertssystemet. Da brukes Namespaces:

    1. Stop docker: $sudo systemctl stop docker
    2. Start med Namespaces tilgengelig: $sudo dockerd --userns-remap=default &

    Dette starter docker med dockermap user og group opprettes og mappes mot ikke-priviligerte uid og gid - "ranges" i /etc/subuid og /etc/subgid - filene.

    Sjekk at bruker-navnerommet er riktig:
    $docker info
    Docker Root Dir: /var/lib/docker/165536.165536 viser at det kjøres i et eget navnerom. Det vanlige root-dir er: Docker Root Dir: /var/lib/docker

    Ved å nå kjøre $sudo docker images får du ingen tilgjengelige images, som viser at docker deamon nå kjører i et eget navnerom der ingenting annet er tilgjengelig.

    Vi kan kjøre som root, men denne root-brukeren har da bare tilgang til navnerommet vi nå kjører docker i:

    sudo docker run -it --rm -v /bin:/host/bin busybox /bin/sh
    Denne mounter /bin til /host/bin

    Kjør $id i containeren, som viser root.

    Prøv å slette noe i /bin (f.eks: $rm host/bin/sh), dette får man ikke lov til, da man ikke har root-tilgang i host.




