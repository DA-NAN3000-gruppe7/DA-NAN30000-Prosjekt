#!/usr/bin/env python3
import sys, os, io, urllib
import sqlite3
import cgi
from cgi import FieldStorage
import requests
import xml.dom.minidom
import xml.etree.ElementTree as ET
import hashlib
import secrets

# Printing headers for xml
print('Content-type:text/xml\n')
print('<?xml version="1.0"?>')

# Connecting to db
conn = sqlite3.connect('db1')

# Get path from url
myPathSelf = os.environ.get('PATH_INFO')

# Get request-method
reqMethod = os.environ.get('REQUEST_METHOD')

# POST: Legger til nytt dikt i databasen eller sjekker loggin
if reqMethod == "POST":

        myPathSelf = os.environ.get('PATH_INFO') # Get the path
        parts = myPathSelf.split("/") # Henter ut første /pathstring
        
        # Hvis "login"
        # -------------------------
        if(parts[1] == "login"):
                
                # Henter og parser xml data inn -------
                query_string = sys.stdin.read() # Leser inn kropp med xml fra forespørsel
                root = ET.fromstring(query_string)

                userIn = ""
                passwordIn = ""

                for itemUser in root.findall('./username'):
                        userIn = itemUser.text

                for itemPassword in root.findall('./password'):
                        passwordIn = itemPassword.text

                # Lager sql-spørring
                sql_get_user_query = "SELECT * FROM Bruker WHERE epostadresse = '" + userIn + "'"

                # Kjører sql-spørring mot db
                cursor = conn.execute(sql_get_user_query)
                records = cursor.fetchall()
                
                dbpassword = ""

                for row in records:
                        dbpassword = row[1] # Henter passord
                
                if passwordIn == dbpassword:
                        # Success
                        # Opprette ny sesjon
                        new_session_id = secrets.token_urlsafe(16) # Lager ny sesjons-id
                        sql_string = "INSERT INTO Sesjon (sesjonsID,epostadresse) VALUES ('" + new_session_id + "', '" + userIn + "')"
                        conn.execute(sql_string)
                        conn.commit()

                        # Sende status tilbake fra REST api
                        print("<result><status>1</status><statustext>Bruker logget inn: " + userIn + "</statustext><sessionid>" + new_session_id + "</sessionid><data></data></result>") # Respons i xml-format
                else:
                        # Fail
                        # Sende status tilbake fra REST api
                        print("<result><status>0</status><statustext>Logg inn failed</statustext><sessionid></sessionid><data></data></result>") # Respons i xml-format

        elif(parts[1] == "logout"):
                # Slette sesjon
                query_string = sys.stdin.read() # Leser inn kropp med xml fra forespørsel
                root = ET.fromstring(query_string)

                for item in root.findall('./sessionid'):
                        session_id_to_logout = item.text

                # Lager sql-spørring
                sql_delete_query = "DELETE FROM Sesjon WHERE sesjonsID = '" + str(session_id_to_logout) + "'"

                # Kjører sql-spørring mot db
                conn.execute(sql_delete_query)
                conn.commit()

                print("<result><status>1</status><statustext>Logg ut success</statustext><sessionid>" + session_id_to_logout + "</sessionid><data></data></result>") # Respons i xml-format

        # Sjekker om bruker er logget inn, dvs har en aktiv sesjon i databasen
        elif(parts[1] == "loginstatus"):

                # Sjekke loginstatus og returnere
                query_string = sys.stdin.read() # Leser inn kropp med xml fra forespørsel
                root = ET.fromstring(query_string)

                for item in root.findall('./sessionid'):
                        session_id_to_check = item.text

                # Lager sql-spørring
                sql_check_query = "SELECT * FROM Sesjon WHERE sesjonsID = '" + str(session_id_to_check) + "'"
                
                # Kjører sql-spørring mot db
                cursor = conn.execute(sql_check_query)
                records = cursor.fetchall()

                if records is None:
                        # Ingen bruker har aktiv sesjon
                        print("<result><status>0</status><statustext>Bruker ikke logget inn</statustext><sessionid>" + session_id_to_check + "</sessionid><user></user><data></data></result>") # Respons i xml-format
                else:
                        # Det finnes en aktiv sesjon
                        emailIn = ""
                        for row in records:
                            emailIn = row[1] # Henter epostadresse
                        
                        print("<result><status>1</status><statustext>Bruker er logget inn</statustext><sessionid>" + session_id_to_check + "</sessionid><user>" + emailIn + "</user><data></data></result>") # Respons i xml-format


        # Hvis ikke "login"
        # -------------------------
        else:
                # Henter og parser xml -------
                query_string = sys.stdin.read() # Leser inn kropp med xml fra forespørsel
                root = ET.fromstring(query_string)
                
                textIn = ""

                # Dikttekst
                for itemText in root.findall('./text'):
                        textIn = itemText.text

                # Get user from session
                # Get cookie from request
                cookiesIn = os.environ.get('HTTP_COOKIE')
                string_session_id = ""

                # Get session value
                cookieValues = cookiesIn.split('=')
                string_session_id = cookieValues[1]

                # Get user with session
                sql_check_query = "SELECT * FROM Sesjon WHERE sesjonsID = '" + str(string_session_id) + "'"
                
                # Kjører sql-spørring mot db
                cursor1 = conn.execute(sql_check_query)
                records1 = cursor1.fetchall()

                if records1 is None:
                    # Ingen bruker har aktiv sesjon
                    print("<result><status>0</status><statustext>Bruker ikke logget inn</statustext><sessionid></sessionid><data></data></result>") # Respons i xml-format
                else:
                    # Det finnes en aktiv sesjon
                    emailIn = ""
                    for row in records1:
                        emailIn = row[1] # Henter epostadresse
                    
                    # Legg dikt inn i db
                    sql_string = "INSERT INTO Dikt (dikt,epostadresse) VALUES ('" + textIn + "', '" + emailIn + "')"
                    conn.execute(sql_string)
                    conn.commit()
                    print("<result><status>1</status><statustext>Success post with content " + textIn + "</statustext><data></data></result>") # Respons i xml-format

# GET: Henter dikt fra databasen
if reqMethod == "GET":
        myPathSelf = os.environ.get('PATH_INFO') # Get the path
        #myPathSelf = "/diktsamling/dikt/6" # !TESTDATA!
        parts = myPathSelf.split("/")
        
        if(parts[3] != ""):
            cursor = conn.execute("SELECT * FROM Dikt WHERE diktId = ?", (parts[3],))
            records = cursor.fetchall()
            for row in records:
                outstring = "<diktbase><diktID>" + str(row[0]) + "</diktID><dikt>" + row[1] + "</dikt><epostadresse>" + row[2] + "</epostadresse></diktbase>"
            print('<!DOCTYPE note SYSTEM "diktsamling.dtd">')
            print(outstring)
            cursor.close()
        else:
            # Get dikt
            cursor = conn.execute("SELECT * FROM Dikt")
            records = cursor.fetchall()
            
            # Writing xml to respons
            outstring = "<diktbase>"
            for row in records:
                outstring += "<dikt><diktID>" + str(row[0]) + "</diktID><dikt>" + row[1] + "</dikt><epostadresse>" + row[2] + "</epostadresse></dikt>"
            outstring += "</diktbase>"
            print('<!DOCTYPE note SYSTEM "diktsamling.dtd">')
            print(outstring)
            cursor.close()
# End GET ----

# DELETE: Sletter dikt fra databasen
if reqMethod == "DELETE":
        myPathSelf = os.environ.get('PATH_INFO') # Get the path
        parts = myPathSelf.split("/")
        
        if(parts[3] != ""): # Hvis id er angitt i path
                diktIdIn = parts[3]
                sql_delete_query = "DELETE FROM Dikt WHERE diktID = " + str(diktIdIn)
                conn.execute(sql_delete_query)
                conn.commit()

                print("<result><status>1</status><statustext>Success delete a dikt from db</statustext><data></data></result>") # Respons i xml-format
        
        else: # Hvis ikke id er angitt, slette alle diktene til brukeren
            userEmail = ""
            
            # Get cookie from request
            cookiesIn = os.environ.get('HTTP_COOKIE')
            string_session_id = ""

            # Get session value
            cookieValues = cookiesIn.split('=')
            string_session_id = cookieValues[1]

            # Get user with session
            sql_check_query = "SELECT * FROM Sesjon WHERE sesjonsID = '" + str(string_session_id) + "'"
                
            # Kjører sql-spørring mot db
            cursor = conn.execute(sql_check_query)
            records = cursor.fetchall()
            
            if records is None:
                # Ingen bruker har aktiv sesjon
                print("<result><status>0</status><statustext>Delete all not possible - no user logged in</statustext><data></data></result>") # Respons i xml-format
            
            else:

                # Det finnes en aktiv sesjon
                for row in records:
                    userEmail = row[1] # Henter epostadresse
                
                sql_delete_all_query = "DELETE FROM Dikt WHERE epostadresse = '" + str(userEmail) + "'"
                conn.execute(sql_delete_all_query)
                conn.commit()
                print("<result><status>1</status><statustext>Success delete all</statustext><data></data></result>") # Respons i xml-format
        
# PUT: Skal oppdatere eksisterende dikt med ny tekst - kun egne dikt
if reqMethod == "PUT":

        # Henter og parser xml -------
        query_string = sys.stdin.read() # Leser inn kropp med xml fra forespørsel
        root = ET.fromstring(query_string)

        idIn = ""
        textIn = ""

        for itemText in root.findall('./text'):
            textIn = itemText.text

        myPathSelf = os.environ.get('PATH_INFO') # Get the path
        parts = myPathSelf.split("/")
        idIn = parts[3]
        print("String: ",textIn)
        # Get cookie from request
        cookiesIn = os.environ.get('HTTP_COOKIE')
        string_session_id = ""

        # Get session value
        cookieValues = cookiesIn.split('=')
        string_session_id = cookieValues[1]

        # Get user with session
        sql_check_query = "SELECT * FROM Sesjon WHERE sesjonsID = '" + str(string_session_id) + "'"
            
        # Kjører sql-spørring mot db
        cursor = conn.execute(sql_check_query)
        records = cursor.fetchall()
        
        if records is None:
            # Ingen bruker har aktiv sesjon
            print("<result><status>0</status><statustext>Updating dikt failed - no user logged in</statustext><data></data></result>") # Respons i xml-format
        else:
            if(idIn != ""):
                sql_update_query = "UPDATE Dikt SET dikt =  '" + textIn + "' WHERE diktID = '" + idIn + "'"
                conn.execute(sql_update_query)
                conn.commit()
                print("<result><status>1</status><statustext>Success put</statustext><data></data></result>") # Respons i xml-format
# Closing db-connection
conn.close()