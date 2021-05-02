#!/bin/bash

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }


POEM="Heihei"

username="henrik@mixdesign.no"
password="gruppe7"

usernameDecoded=$(urldecode "$username")
hashpassword=($(echo -n $password | sha256sum ))


DATA="<user><username>"$usernameDecoded"</username><password>"$hashpassword"</password></user>"

echo -en $DATA

URL="http://localhost:8000/cgi-bin/rest.py/login"



curl -X "POST" "$URL" -H "Accept: application/xml" --data "$DATA" 