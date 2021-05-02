#!/bin/bash

# MP3-RESTapi
# Gruppe 7
# -------------------------------------

read BODY

# Set variables
isLoggedIn="0"
currentSessionId=""
currentUserEmail=""

# Printing headers for rest-api
echo 'Content-type:text/xml'
echo 'Access-Control-Allow-Origin: http://localhost'
echo 'Access-Control-Allow-Headers: Accept, Content-Type'
echo 'Access-Control-Allow-Credentials: true'
echo 'Access-Control-Allow-Methods: GET, POST, PUT, DELETE'

# Database-path and name
database_path="db1"

# Get path from url
myPathSelf=$REQUEST_URI

# Get cookie
myCookie=$HTTP_COOKIE

# Get request-method
reqMethod=$REQUEST_METHOD
#reqMethod="PUT" # TESTVALUE

# Functions -----------------------

function checkLoggedIn() { 
    IFS='=' # Set delimiter
    read -a parts <<<"$HTTP_COOKIE" # Get cookie-string as array delimeter by "="
    sessionIdIn=${parts[1]} # Get the session-id
    #sessionIdIn="ttw13hidhjZkzRW7yQba5Q1" # For testing purposes

    listOut=$(sqlite3 "$database_path" "SELECT * FROM Sesjon WHERE sesjonsID = '$sessionIdIn'")
    IFS=$'\n' # Set delimiter
    read -d '\n' -ra rowsOut <<< "$listOut"
    numRows=${#rowsOut[@]}
    sessionContent=${rowsOut[0]}
    
    if [[ $numRows>0 ]]; then
        # Session exists
        IFS=$'|' # Set delimiter
        IFS=$'|' read sessionIdInp sessionEmail <<< "$sessionContent"
        currentSessionId=$sessionIdInp # Set user session variable
        currentUserEmail=$sessionEmail # Set user email variable
        isLoggedIn="1"
    else
        # Session does not exists
        isLoggedIn="0"
    fi
}

# If request-method is POST
if [[ $reqMethod = "DELETE" ]]; then
    
    checkLoggedIn # Check loginstatus, set loginstatus variable

    # Read path and split
    IFS='/' # Set delimiter
    read -a parts <<<"$myPathSelf" # Get path as array delimeter by "/"
    IFS='\' # Reset delimiter

    # Do delete one dikt
    if [[ ${parts[5]} != "" ]]; then
        
        # Delete a single dikt from db
        sqlite3 "$database_path" "DELETE FROM Dikt WHERE diktID = '${parts[5]}'"

        # Creating respons body
        outstring='<?xml version="1.0"?>'
        outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
        outstring+='<result><status>1</status><statustext>Dikt deleted: '${parts[5]}'</statustext></result>'
        
        strlength=${#outstring} # get length of respons body
        
        echo "Content-Length: "$strlength # Writing respons header
        echo "" # Separate header with empty line
        echo $outstring # Writing respons body
        
    else
        # Do delete all dikt
        sqlite3 "$database_path" "DELETE FROM Dikt WHERE epostadresse = '$currentUserEmail'"

        # Creating respons body
        outstring='<?xml version="1.0"?>'
        outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
        outstring+='<result><status>1</status><statustext>All dikt deleted for user: '$currentUserEmail'- and with cookie: '$HTTP_COOKIE'</statustext></result>'
        
        strlength=${#outstring} # get length of respons body
        
        echo "Content-Length: "$strlength # Writing respons header
        echo "" # Separate header with empty line
        echo $outstring # Writing respons body
    fi

fi

# If request-method is POST
if [[ $reqMethod = "POST" ]]; then

    doCreateDikt="1" # Control-variable
    checkLoggedIn # Check loginstatus, set loginstatus variable

    # Read path and split
    IFS='/' # Set delimiter
    read -a parts <<<"$myPathSelf" # Get path as array delimeter by "/"
    IFS='\' # Set delimiter

    # Do login
    if [[ ${parts[3]} = "login" ]]; then
    
        doCreateDikt="0"
        
        xmlIn=$BODY
        usernameIn=$(xmllint --xpath "//username/text()" - <<<"$xmlIn") # Parsing xml user
        passwordIn=$(xmllint --xpath "//password/text()" - <<<"$xmlIn") # Parsing xml password

        listOut=$(sqlite3 "$database_path" "SELECT * FROM Bruker WHERE epostadresse = '$usernameIn'")
        read -d '\n' -ra rowsOut <<< "$listOut"
        numRows=${#rowsOut[@]}
        
        userContent=${rowsOut}
            
        if [[ $numRows>0 ]]; then
            # User exists
            IFS='|' read uEmail uPassword uFname uLname <<< "$userContent"
            currentUserEmail=$uEmail # Set user email variable
            currentPasswordHashed=$uPassword # Set user password variable
            
            # Get sha256-hash from password input
            hashpassword=$(echo -n $passwordIn | sha256sum | head -c 64) # Hasing input password

            if [[ $hashpassword = $currentPasswordHashed ]]; then # If password match

                # Generate new session-id
                new_session_id=$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
                
                # Insert dikt into db
                sqlite3 "$database_path" "insert into Sesjon (sesjonsID,epostadresse) \
                values (\"$new_session_id\",\"$currentUserEmail\");"

                # Send response
                outstring='<?xml version="1.0"?>'
                outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
                outstring+="<result><status>1</status><statustext>Bruker logget in: -"$hashpassword"--"$currentPasswordHashed"</statustext><sessionid>"$new_session_id"</sessionid><user></user></result>" # XML-respons
                strlength=${#outstring} # get length of respons body
                echo 'Content-Length: '$strlength # Writing respons header
                echo "" # Separate header with empty line
                echo $outstring # Writing respons body
            else
                outstring='<?xml version="1.0"?>'
                outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
                outstring+="<result><status>0</status><statustext>Feil bruker eller passord</statustext><sessionid></sessionid><user></user></result>" # XML-respons
                strlength=${#outstring} # get length of respons body
                echo 'Content-Length: '$strlength # Writing respons header
                echo "" # Separate header with empty line
                echo $outstring # Writing respons body
            fi
        else
            # User does not exist in db
            outstring='<?xml version="1.0"?>'
            outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
            outstring+="<result><status>0</status><statustext>Bruker eksisterer ikke</statustext><sessionid></sessionid><user></user></result>" # XML-respons
            #outstring=urldecode "$outstring"
            strlength=${#outstring} # get length of respons body
            echo 'Content-Length: '$strlength # Writing respons header
            echo "" # Separate header with empty line
            echo $outstring # Writing respons body
        fi

    fi # End login

    # Do logout
    if [[ ${parts[3]} = "logout" ]]; then 

        doCreateDikt="0"

        xmlIn=$BODY
        session_id_to_logout=$(xmllint --xpath "//sessionid/text()" - <<<"$xmlIn") # Parsing xml sessionid

        # Delete session from db
        sqlite3 "$database_path" "DELETE FROM Dikt WHERE diktID = '${parts[5]}'"

        # Send respons
        outstring='<?xml version="1.0"?>'
        outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
        outstring+="<result><status>1</status><statustext>Bruker er logget inn</statustext><sessionid>"$currentSessionId"</sessionid><user>"$currentUserEmail"</user></result>" # Respons i xml-format
        strlength=${#outstring} # get length of respons body
        echo "Content-Length: "$strlength # Writing respons header
        echo "" # Separate header with empty line
        echo $outstring # Writing respons body
    fi

    # Do loginstatus
    if [[ ${parts[3]} = "loginstatus" ]]; then
        
        doCreateDikt="0"

        xmlIn=$BODY
        session_id_to_check=$(xmllint --xpath "//sessionid/text()" - <<<"$xmlIn") # Parsing xml sessionid

        listOut=$(sqlite3 "$database_path" "SELECT * FROM Sesjon WHERE sesjonsID = '$session_id_to_check'")
        IFS=$'\n' # Set delimiter
        read -ra rowsOut <<< "$listOut"
        numRows=${#rowsOut[@]}
        
        if [[ $numRows != "" ]]; then
            # Session exists
            IFS='|' read ses mail <<< "$listOut"
            currentSessionId=$ses # Set user session variable
            currentUserEmail=$mail # Set user email variable

            isLoggedIn="1"

            # Print respons
            outstring='<?xml version="1.0"?>'
            outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
            outstring+="<result><status>1</status><statustext>Bruker er logget inn med brukerssa: "$currentUserEmail"</statustext><sessionid>"$currentSessionId"</sessionid><user>"$currentUserEmail"</user></result>" # Respons i xml-format
            strlength=${#outstring} # get length of respons body
            echo "Content-Length: "$strlength # Writing respons header
            echo "" # Separate header with empty line
            echo $outstring # Writing respons body
        else
            # Is not logged in
            outstring='<?xml version="1.0"?>'
            outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
            outstring+="<result><status>0</status><statustext>Bruker ikke logget inn</statustext><sessionid>"$currentSessionId"</sessionid><user></user></result>" # XML-respons
            #outstring=urldecode "$outstring"
            strlength=${#outstring} # get length of respons body
            echo 'Content-Length: '$strlength # Writing respons header
            echo "" # Separate header with empty line
            echo $outstring # Writing respons body
        fi

    fi

    # No other action, create dikt will be done
    # Do create dikt
    if [[ $doCreateDikt = "1" && $isLoggedIn = "1" ]]; then

        checkLoggedIn # Check loginstatus, set loginstatus variable

        textIn=""
        xmlIn=$BODY
        epostadresse=$currentUserEmail
        textIn=$(xmllint --xpath "//text/text()" - <<<"$xmlIn") # Parsing xml <dikt><text></text></dikt>

        # Insert dikt into db
        sqlite3 "$database_path" "insert into Dikt (dikt,epostadresse) \
        values (\"$textIn\",\"$epostadresse\");"

        # Creating respons body
        outstring='<?xml version="1.0"?>'
        outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
        outstring+="<result><status>1</status><statustext>Success post with content "$textIn" fra bruker "$currentUserEmail" </statustext></result>"
        
        strlength=${#outstring} # get length of respons body
        
        echo "Content-Length: "$strlength # Writing respons header
        echo "" # Separate header with empty line
        echo $outstring # Writing respons body
    else
        # No user logged in, return status 0
        outstring='<?xml version="1.0"?>'
        outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
        outstring+='<result><status>0</status><statustext>No user logged in</statustext></result>'
    fi
fi # End post

# If request-method is PUT
if [[ $reqMethod = "PUT" ]]; then

    checkLoggedIn

    xmlIn=$BODY
    textIn=$(xmllint --xpath "//text/text()" - <<<"$xmlIn") # Parsing xml <dikt><text></text></dikt>

    # Read path and split
    IFS='/' # Set delimiter
    read -a parts <<<"$myPathSelf" # Get path as array delimeter by "/"
    IFS='\' # Reset delimiter

    # Do put if id and isloggedin
    if [[ ${parts[5]} != "" && $isLoggedIn = "1" ]]; then
        
        # Insert dikt into db
        sqlite3 "$database_path" "UPDATE Dikt SET dikt = '$textIn' WHERE diktID = '${parts[5]}' AND epostadresse = '$currentUserEmail'"

        # Creating respons body
        outstring='<?xml version="1.0"?>'
        outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
        outstring+='<result><status>1</status><statustext>Success put dikt</statustext></result>'
        
        strlength=${#outstring} # get length of respons body
        
        echo "Content-Length: "$strlength # Writing respons header
        echo "" # Separate header with empty line
        echo $outstring # Writing respons body
    else
        # Not logged in or no dikt id
        # Creating respons body
        outstring='<?xml version="1.0"?>'
        outstring+='<!DOCTYPE result SYSTEM "http://localhost:80/dtd/result.dtd">'
        outstring+='<result><status>0</status><statustext>Missing id or not logged in put dikt</statustext></result>'
        
        strlength=${#outstring} # get length of respons body
        
        echo "Content-Length: "$strlength # Writing respons header
        echo "" # Separate header with empty line
        echo $outstring # Writing respons body
    fi
fi # End put

# If request-method is GET
if [[ $reqMethod = "GET" ]]; then

    echo "" # Empty line after header
    # Read path and split
    IFS='/' # Set delimiter
    read -a parts <<<"$myPathSelf" # Get path as array delimeter by "/"
    
    if [[ ${parts[5]} != "" ]]; then
        printf "<diktbase>"
        # Get from db and printing xml - one dikt
        sqlite3 "$database_path" "SELECT * FROM Dikt WHERE diktID = '${parts[5]}'" | awk -F'|' '
        # sqlite output line - pick up fields and store in arrays
        { diktID[++i]=$1; dikt[i]=$2; epostadresse[i]=$3 }
        END {
            
            for(j=1;j<=i;j++){
                printf "<dikt>"
                printf "<diktID>%s</diktID>",diktID[j]
                printf "<dikt>%s</dikt>",dikt[j]
                printf "<epostadresse>%s</epostadresse>",epostadresse[j]
                printf "</dikt>"
            }
            
        }' | tr '|' '"'
        # End printing xml one dikt
        printf "</diktbase>"
    else
        # Get from db and printing xml - all dikt
        sqlite3 "$database_path" "SELECT * FROM Dikt" | awk -F'|' '
        # sqlite output line - pick up fields and store in arrays
        { diktID[++i]=$1; dikt[i]=$2; epostadresse[i]=$3 }
        END {
            printf "<diktbase>";
            for(j=1;j<=i;j++){
                printf "<dikt>"
                printf "<diktID>%s</diktID>",diktID[j]
                printf "<dikt>%s</dikt>",dikt[j]
                printf "<epostadresse>%s</epostadresse>",epostadresse[j]
                printf "</dikt>"
            }
            printf "</diktbase>";
        }' | tr '|' '"'
        # End printing xml all dikt
    fi
fi

exit 0