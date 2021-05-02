#!/bin/bash

# Functions
function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

# Body-content
read BODY

# Evaluate and get input data
allInData=$QUERY_STRING$BODY # Combine post and get data
querystringArray=(${allInData//&/ })
debugtext="--- Start ---"
loginstatus="0"

# Setting variables
reqMethod=$REQUEST_METHOD # Request method
queryString=$QUERY_STRING # Query-string content
form=$BODY # Body data content carried in request
statustext="" # Status text used for debugging
cookie_string="" # Cookie-string to output to browser
current_cookie_id_value="" # Current session-id stored in cookie
current_user="" # User logged in

# Get cookie value (holding session id) if it exists
cookie=$HTTP_COOKIE
arrayPairsCookie=(${cookie//=/ })
current_cookie_id_value=${arrayPairsCookie[1]}

# Input values from cgi-form
# allInData har all data i key=value&key=value
todoPair=${querystringArray[0]}
todoArray=(${todoPair//=/ })
todo=${todoArray[1]} # todo-text

# setuser = form.getvalue("user")
# setlogout = form.getvalue("logout")
# isset = str(isset)

# Check if logout is sent from form input
# Start logout ----------------------------------------------------------
if [[ $todo = "logout" ]];
then
    cookie_string="Set-cookie:user_session=0; expires=Wed, 14-Feb-2001 05:53:40 GMT;"
    session_to_logout=$current_cookie_id_value
    url_auth="http://host.docker.internal:8080/cgi-bin/rest.sh/logout"
    data="<?xml version='1.0'?><!DOCTYPE result SYSTEM 'http://localhost:80/dtd/user.dtd'><user><sessionid>"$session_to_logout"</sessionid></user>"
    resp=$(curl -H "Accept: application/xml" --cookie "user_session=$current_cookie_id_value" -X POST --data "$data" "$url_auth")
    
    STATUSCODE=$(xmllint --xpath "//status/text()" - <<<"$resp") # Parsing xml <status></status>

    if [[ $STATUSCODE = "1" ]]; # If logged out successfully
    then
        loginstatus="0"
        debugtext+="<br/>Logget ut"
        cookie_string="Set-cookie:user_session=0; expires=Wed, 14-Feb-2001 05:53:40 GMT;"
    fi

    if [[ $STATUSCODE = "0" ]]; # If not logged out successfully
    then
        debugtext+="<br/>Kunne ikke logge ut"
    fi

fi
# End logout ----------------------------------------------------------

# Check if login is sent from form input
# Start login ----------------------------------------------------------
if [[ $todo = "login" ]];
then

    # Getting username and password from input
    IN=$BODY
    arrayPairs=(${IN//&/ })
    INUSER=${arrayPairs[1]}
    INPASS=${arrayPairs[2]}
    username_value=(${INUSER//=/ })
    password_value=(${INPASS//=/ })
    username=${username_value[1]} # Username variable
    password=${password_value[1]} # Password variable
    usernameDecoded=$(urldecode "$username")
    debugtext+="<br/>Username: "$usernameDecoded
    
    # Set auth url, data and do curl-request
    url_auth="http://host.docker.internal:8080/cgi-bin/rest.sh/login"
    data="<?xml version='1.0'?><!DOCTYPE result SYSTEM 'http://localhost:80/dtd/user.dtd'><user><username>"$usernameDecoded"</username><password>"$password"</password></user>"
    resp=$(curl -H "Accept: application/xml" --cookie "user_session=$current_cookie_id_value" -X POST --data "$data" "$url_auth")
    
    # Status code from xml-respons
    STATUSCODE=$(xmllint --xpath "//status/text()" - <<<"$resp") # Parsing xml <status></status>
    NEWSESSIONID=$(xmllint --xpath "//sessionid/text()" - <<<"$resp") # Parsing xml <sessionid></sessionid>

    if [[ $STATUSCODE = "1" ]]; # If logged in successfully
    then
        current_user=$usernameDecoded
        loginstatus="1"
        debugtext+="<br/>Login respons: "$resp
        cookie_string="Set-cookie:user_session="$NEWSESSIONID
    fi

    if [[ $STATUSCODE = "0" ]]; # If not logged in successfully
    then
        loginstatus="0"
        debugtext+="<br/>Feil ved innlogging"
        cookie_string=""
    fi

fi
# End login ----------------------------------------------------------

# Checking login status against session in DB
# Start ----------------------------------------------------------
if [[ $current_cookie_id_value != "" ]] && [[ $todo != "logout" ]]; # If cookie-value is set and not logging out
then

    url_auth_check="http://host.docker.internal:8080/cgi-bin/rest.sh/loginstatus"
    data_check="<?xml version='1.0'?><!DOCTYPE result SYSTEM 'http://localhost:80/dtd/check.dtd'><check><sessionid>"$current_cookie_id_value"</sessionid></check>"
    resp=$(curl -H "Accept: application/xml" --cookie "user_session=$current_cookie_id_value" -X POST --data "$data_check" "$url_auth_check")
    debugtext+="<br/>Loginstatuss xml: "$resp
    # Status code from xml-respons
    STATUSCODE=$(xmllint --xpath "//status/text()" - <<<"$resp") # Parsing xml <status></status>
    USER=$(xmllint --xpath "//user/text()" - <<<"$resp") # Parsing xml <user></user>
    debugtext+="<br/>Loginstatuscode: "$STATUSCODE" - User: "$USER
    loginstatus=$STATUSCODE # Set variable for loginstatus to use for check later
    current_user=$USER
fi
# End login status check ----------------------------------------------------------

# Writing head
echo "Content-type: text/html"

# Writing cookie
if [[ $cookie_string != "" ]]; # If cookie-value is set
then
    echo $cookie_string
fi

# Writing empty line
echo ""

# Writing first part of html
echo '<html>'
echo '<head>'
echo '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'
echo '<title>Gruppe 7 - dikteditor</title>'
#echo '<style>p { margin-top: 0px; } input[type=text] { padding: 6px; } input[type=password] { padding: 6px; } input[type=submit] { padding: 8px; color: #fff; border: 0px; border-radius: 3px; background-color: #339DFF; } form { padding:0;margin:0; } body { font-family: arial; } label { font-size: 12px; display: block; margin-top: 15px; margin-bottom: 5px; } .form-div { margin: 15px; border-radius: 5px; border: 2px solid #ccc; padding: 30px; } .status-field { border: 2px solid #ccc; background-color: #fff9db; padding: 30px; border-radius: 5px; margin: 15px;  }</style>'
echo '<link rel="stylesheet" href="http://localhost:80/css/mp3style.css" />'
echo '</head>'
echo '<body>'

# Checking if todo = Get
# Start ----------------------------------------------------------
if [[ $todo = "Get" ]]; # If todo = "Get" - get a dikt by id from database
then
    # Get input:diktid from form
    IN=$BODY
    arrayPairs=(${IN//&/ })
    INVALUE=${arrayPairs[1]}
    input_value=(${INVALUE//=/ })
    diktid=${input_value[1]} # diktid variable

    if [[ $diktid != "" ]]; # If not empty
    then
        url="http://host.docker.internal:8080/cgi-bin/rest.sh/diktbase/dikt/"$diktid
        resp=$(curl -H "Accept: application/xml" --cookie "user_session=$current_cookie_id_value" -X GET "$url")
        #echo RESPONS GET: $resp
        debugtext+="<br/>"$resp
    fi
    if [[ $diktid = "" ]]; # If empty
    then    
        debugtext+="<br/>Diktid er ikke angitt - kan ikke hente dikt"
    fi
fi

# Checking if todo = Getall - get all dikt
# Start ----------------------------------------------------------
if [[ $todo = "Getall" ]]; # If todo = "Getall" - get all dikt
then
    url="http://host.docker.internal:8080/cgi-bin/rest.sh/diktbase/dikt/"
    resp=$(curl -H "Accept: application/xml" --cookie "user_session=$current_cookie_id_value" -X GET "$url")
    debugtext+="<br/>"$resp
fi

# Checking if todo = Post (create new dikt)
# Start ----------------------------------------------------------
if [[ $todo = "Post" ]]; # If todo = post - Create a new dikt in database
then
    # Get input:dikttekst from form
    IN=$BODY
    arrayPairs=(${IN//&/ })
    INVALUE=${arrayPairs[1]}
    input_value=(${INVALUE//=/ })
    dikttekstin=${input_value[1]} # dikttekst text
    dikttekst=$(urldecode "$dikttekstin") # Decoding string

    url="http://host.docker.internal:8080/cgi-bin/rest.sh/diktbase/dikt/"
    data="<?xml version='1.0'?><!DOCTYPE result SYSTEM 'http://localhost:80/dtd/dikt.dtd'><dikt><text>"$dikttekst"</text></dikt>"
    resp=$(curl -H "Accept: application/xml" --cookie "user_session=$current_cookie_id_value" -X POST --data "$data" "$url")

    debugtext+="<br/>"$resp
fi
# End Post ----------------------------------------------------------

# Checking if todo = Delete (delete a dikt)
# Start ----------------------------------------------------------
if [[ $todo = "Delete" ]]; # If todo = Delete - Delete a dikt in db
then
    # Get input:diktid from form
    IN=$BODY
    arrayPairs=(${IN//&/ })
    INVALUE=${arrayPairs[1]}
    input_value=(${INVALUE//=/ })
    diktid=${input_value[1]} # diktid variable

    if [[ $diktid != "" ]]; # If not empty
    then
        url="http://host.docker.internal:8080/cgi-bin/rest.sh/diktbase/dikt/"$diktid
        resp=$(curl --cookie "user_session=$current_cookie_id_value" -X DELETE "$url")
        debugtext+="<br/>Delete a dikt: "$resp
    fi
    if [[ $diktid = "" ]]; # If empty
    then    
        debugtext+="<br/>Diktid er ikke angitt - kan ikke slette dikt"
    fi
fi
# End Delete ----------------------------------------------------------

# Checking if todo = Deleteall (Deleteall all users dikt)
# Start ----------------------------------------------------------
if [[ $todo = "Deleteall" ]]; # If todo = Deleteall
then
        url="http://host.docker.internal:8080/cgi-bin/rest.sh/diktbase/dikt/"
        resp=$(curl -H "Accept: application/xml" --cookie "user_session=$current_cookie_id_value" -X DELETE "$url")
        debugtext+="<br/>Deleteall: "$resp
fi
# End Deleteall ----------------------------------------------------------

# Checking if todo = Put (edit own dikt)
# Start ----------------------------------------------------------
if [[ $todo = "Put" ]]; # If todo = put - Edit own dikt
then
    # Get input:dikttekst and diktid from form
    IN=$BODY
    arrayPairs=(${IN//&/ })
    INID=${arrayPairs[1]}
    INTEXT=${arrayPairs[2]}
    input_id_pair=(${INID//=/ })
    input_text_pair=(${INTEXT//=/ })
    diktidin=${input_id_pair[1]} # dikttekst id
    dikt_id=$(urldecode "$diktidin") # Decoding id
    dikttekstin=${input_text_pair[1]} # dikttekst text
    dikt_text=$(urldecode "$dikttekstin") # Decoding string

    url="http://host.docker.internal:8080/cgi-bin/rest.sh/diktbase/dikt/"$dikt_id
    data="<?xml version='1.0'?><!DOCTYPE result SYSTEM 'http://localhost:80/dtd/dikt.dtd'><dikt><text>"$dikt_text"</text></dikt>"
    resp=$(curl -H "Accept: application/xml" --cookie "user_session=$current_cookie_id_value" -X PUT --data "$data" "$url")

    debugtext+="<br/>"$resp
fi
# End Put ----------------------------------------------------------


# Writing status field
echo '<h1>Gruppe 7 - dikteditor - v1.3</h1>'$current_cookie_id_value
echo '<a href="http://localhost:80/index.html">Gå til gruppas nettside</a>'
echo '<div class="status-field">'
echo Debug: $debugtext
echo '</div>' # End status text field

# Writing forms
echo '<div>'

# Form: login-form
if [[ $loginstatus = "0" ]]; # If user not logged in
then
cat << EOF
<div class="form-div">
<p>Du må logge inn</p>
<FORM ACTION="" METHOD="POST">
<INPUT TYPE="hidden" NAME="todo" VALUE="login">
<label for="inp_user">Brukernavn</label>
<INPUT TYPE="text" NAME="username" ID="inp_user" VALUE="">
<label for="inp_password">Passord</label>
<INPUT TYPE="password" NAME="password" ID="inp_password" VALUE="">
<INPUT TYPE="submit" VALUE="Logg inn">
</FORM>
</div>
EOF
fi
# End login form ---------------------------------------

# Form: logout-form
if [[ $loginstatus = "1" ]]; # If user logged in
then
cat << EOF
<div class="form-div">
<p>Du er logget inn som: $current_user</p>
<FORM ACTION="" METHOD="POST">
<INPUT TYPE="hidden" NAME="todo" VALUE="logout">
<INPUT TYPE="submit" VALUE="Logg ut">
</FORM>
</div>
EOF
fi
# End logout form ---------------------------------------

# Form: Create new dikt
if [[ $loginstatus = "1" ]]; # If user logged in
then
cat << EOF
<div class="form-div">
<p>Lag nytt dikt</p>
<FORM ACTION="" METHOD="POST">
<INPUT TYPE="hidden" NAME="todo" VALUE="Post">
<INPUT TYPE="text" NAME="dikttekst" VALUE="">
<INPUT TYPE="submit" VALUE="Lagre nytt dikt">
</FORM>
</div>
EOF
fi

# Form: Change dikt
if [[ $loginstatus = "1" ]]; # If user logged in
then
cat << EOF
<div class="form-div">
<p>Rediger dikt</p>
<FORM ACTION="" METHOD="POST">
<INPUT TYPE="hidden" NAME="todo" VALUE="Put">
<label for="inp_diktid">Angi dikt-id</label>
<INPUT TYPE="text" NAME="diktid" ID="inp_diktid" VALUE="">
<label for="inp_dikttekst">Ny tekst</label>
<INPUT TYPE="text" NAME="dikttekst" ID="inp_dikttekst" VALUE="">
<INPUT TYPE="submit" VALUE="Endre dikt">
</FORM>
</div>
EOF
fi

# Form: Get dikt form
cat << EOF
<div class="form-div">
<p>Hent et dikt</p>
<FORM ACTION="" METHOD="POST">
<INPUT TYPE="hidden" NAME="todo" VALUE="Get">
<label for="inp_diktid">Angi dikt-id</label>
<INPUT TYPE="text" NAME="diktid" id="inp_diktid" VALUE="">
<INPUT TYPE="submit" VALUE="Hent dikt">
</FORM>
</div>
EOF

# Form: Get all dikt form
cat << EOF
<div class="form-div">
<p>Hent alle dikt</p>
<FORM ACTION="" METHOD="POST">
<INPUT TYPE="hidden" NAME="todo" VALUE="Getall">
<INPUT TYPE="submit" VALUE="Hent alle dikt">
</FORM>
</div>
EOF

# Form: Delete a dikt
if [[ $loginstatus = "1" ]]; # If user logged in
then
cat << EOF
<div class="form-div">
<p>Slett et dikt</p>
<FORM ACTION="" METHOD="POST">
<INPUT TYPE="hidden" NAME="todo" VALUE="Delete">
<label for="inp_diktid">Angi dikt-id</label>
<INPUT TYPE="text" NAME="diktid" id="inp_diktid" VALUE="">
<INPUT TYPE="submit" VALUE="Slett dikt">
</FORM>
</div>
EOF
fi

# Form: Delete all (all dikt for logged in user)
if [[ $loginstatus = "1" ]]; # If user logged in
then
cat << EOF
<div class="form-div">
<p>Slett alle mine dikt</p>
<FORM ACTION="" METHOD="POST">
<INPUT TYPE="hidden" NAME="todo" VALUE="Deleteall">
<INPUT TYPE="submit" VALUE="Slett alle dikt">
</FORM>
</div>
EOF
fi

echo '</div>' # End forms div

# Writing last part of html
echo '</body>'
echo '</html>'


exit 0