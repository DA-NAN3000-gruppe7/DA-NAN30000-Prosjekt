//selector for Debug text
const statusField = document.querySelector(".status-field");


//selector for the login form
const loginDiv = document.querySelector("#login-div");

//selectors for non-dynamic forms
const getPoem = document.querySelector("#get-poem");
const getAll = document.querySelector("#get-all-poems");

//default text to be outputted in the debug text field
const DEFAULT_DEBUG_TEXT = "Debug: --- Start --- <br>";


//used to verify session
let current_cookie_id_value = "";


if(document.cookie != "") 
    current_cookie_id_value = document.cookie.split('=')[1];


//service worker
if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register("sw.js")
    .then(registration => console.log(registration))
    .catch(error => alert(error)); 
}


//check if user is already logged in
if(current_cookie_id_value != "") {

    const url = "http://localhost:8000/cgi-bin/rest.sh/loginstatus";
    const post_data = `<check><sessionid>${current_cookie_id_value}</sessionid></check>`;

    fetch(url, {
        method: "POST",
        headers: {
            "Accept": "application/xml"
        },
        body: post_data
    })
    .then(response => response.text())
    .catch(error => alert(error))
    .then(data => {

        statusField.innerHTML = `${DEFAULT_DEBUG_TEXT}Loginstatus xml: ${data}`;


        const xmlData = new DOMParser().parseFromString(data,"text/xml");
        const STATUSCODE = xmlData.getElementsByTagName("status")[0].childNodes[0].nodeValue;
        const USER = xmlData.getElementsByTagName("user")[0].childNodes[0].nodeValue;

        statusField.innerHTML += `<br/>Loginstatuscode: ${STATUSCODE} - User: ${USER}`;

        setLoginEnv(USER);
    });
}


//login, logout, post, put, delete and delete all-- These must be under an event target listener because they are dynamic elements in the DOM
document.addEventListener("click", event => {
    event.preventDefault();

    /*---------------LOGIN---------------*/
    if (event.target && event.target.id == "login") {

        const url = "http://localhost:8000/cgi-bin/rest.sh/login";

        const loginForm = document.querySelector("#login-form");

    
        const username = loginForm.elements.inp_user.value;
        //temporarily commented away while hashing is being implemented in rest.sh
        let password = loginForm.elements.inp_password.value;

        //if missing username or password
        if(username == "" || password == "")
            statusField.innerHTML =`${DEFAULT_DEBUG_TEXT}Brukernavn eller passord mangler`;

        //if valid input   
        else {
            //clear fields
            loginForm.elements.inp_password.value = "";

            const post_data = `<user><username>${username}</username><password>${password}</password></user>`;


            statusField.innerHTML = `${DEFAULT_DEBUG_TEXT} Username: ${username}<br>`;

                
            fetch(url, {
                method: "POST",
                headers: {
                    "Accept": "application/xml"
                },
                body: post_data
            })
            .then(response => response.text())
            .catch(error => alert(error))
            .then(data => {
                


                //parse the XML-response
                const xmlData = new DOMParser().parseFromString(data,"text/xml");
        
                const STATUSCODE = xmlData.getElementsByTagName("status")[0].childNodes[0].nodeValue;
        
        
                //if login succesful
                if(STATUSCODE === "1") {
                    loginForm.elements.inp_user.value = "";
 
                    const NEWSESSIONID = xmlData.getElementsByTagName("sessionid")[0].childNodes[0].nodeValue;

                    document.cookie = `user_session=${NEWSESSIONID}; SameSite=;`;
        
                    statusField.innerHTML += `Logget inn vellykket:  ${data}`;
                
                    setLoginEnv(username);
                }
                //if login failed
                else {
                    statusField.innerHTML += "Feil ved innlogging";
                    document.cookie = "";      
                }
        
            });
        }
        //this is used to simply get to the top of the page to view the debug text field
        window.scrollTo(0, 0);

    }
    /*---------------LOGOUT---------------*/
    else if(event.target && event.target.id == "logout") {

        //sets the cookie to expire immediately
        document.cookie = "user_session=0; expires=Wed, 14-Feb-2001 05:53:40 GMT;";
        
        //send to database to tell that the session should be terminated
        const session_to_logout = current_cookie_id_value;

        const url = "http://localhost:8000/cgi-bin/rest.sh/logout";
        const data = `<user><sessionid>"${session_to_logout}"</sessionid></user>`;

        fetch(url, {
            method: "POST",
            headers: {
                "Accept": "application/xml"
            },
            body: data
        })
        .then(response => response.text())
        .catch(error => alert(error))
        .then(data => {


            //parse XML response
            const xmlData = new DOMParser().parseFromString(data,"text/xml");
            const STATUSCODE = xmlData.getElementsByTagName("status")[0].childNodes[0].nodeValue;
            
            //if logout successful
            if(STATUSCODE == "1") {
                statusField.innerHTML = `${DEFAULT_DEBUG_TEXT}Logget ut`;
                document.cookie = "user_session=0; expires=Wed, 14-Feb-2001 05:53:40 GMT;";

                setLogoutEnv();
            }

            //if logout failed
            else
                statusField.innerHTML = `${DEFAULT_DEBUG_TEXT}Kunne ikke logge ut`
        });
        window.scrollTo(0, 0);

    }

    /*---------------POST---------------*/
    else if(event.target && event.target.id == "create") {

        //get poem to post
        const postPoem = document.querySelector("#create-poem");
        const poem = postPoem.elements.dikttekst.value;



        if(poem == "")
            statusField.innerHTML = `${DEFAULT_DEBUG_TEXT} Diktfeltet er tomt!`;
    
        else {
            const url = "http://localhost:8000/cgi-bin/rest.sh/diktsamling/dikt/"
    
            const data = `<dikt><text>${poem}</text></dikt>`;

            const cookie_data = document.cookie;
    
            fetch(url, {
                method: "POST",
                headers: {
                    "Accept": "application/xml"
                },
                credentials: "include",
                body: data

            })
            .then(response => response.text())
            .catch(error => alert(error))
            .then(data => statusField.innerHTML = `${DEFAULT_DEBUG_TEXT}${data}`);
        }
        //clear the text field
        postPoem.elements.dikttekst.value = "";
        window.scrollTo(0, 0);

    }

    /*---------------PUT---------------*/
    else if(event.target && event.target.id == "update") {

        const updateForm = document.querySelector("#update-poem");

        //get poem to update
        const poemId = updateForm.elements.inp_diktid.value;
        const poem = updateForm.elements.inp_dikttekst.value;

        //if poemID is empty
        if(poemId == "")
            statusField.innerHTML = `${DEFAULT_DEBUG_TEXT}DiktId ikke angitt`;

        //if poem text is empty
        else if(poem == "")
        statusField.innerHTML = `${DEFAULT_DEBUG_TEXT}Dikttekst ikke angitt`;

        //if valid input
        else {
            //clear text fields
            updateForm.elements.inp_diktid.value = "";
            updateForm.elements.inp_dikttekst.value = "";

            const url = `http://localhost:8000/cgi-bin/rest.sh/diktsamling/dikt/${poemId}`;
            
            const data = `<dikt><text>${poem}</text></dikt>`;

            fetch(url, {
                method: "PUT",
                headers: {
                    "Content-Type": "application/xml",
                    "Accept": "application/xml"
                },
                credentials: "include",
                body: data
            })
            .then(response => response.text())
            .catch(error => alert(error))
            .then(data => statusField.innerHTML = `${DEFAULT_DEBUG_TEXT}${data}`)
        }

        window.scrollTo(0, 0);
    }

    /*---------------DELETE---------------*/
    else if(event.target && event.target.id == "delete") {


        //get poem to delete
        const poemId = document.querySelector("#delete-poem").elements.inp_diktid.value;

        //if ID is specified
        if(poemId != "") {
            const url = `http://localhost:8000/cgi-bin/rest.sh/diktsamling/dikt/${poemId}`;

            fetch(url, {
                method: "DELETE",
                headers: {
                    "Content-Type": "application/xml",
                    "Accept": "application/xml"
                },
                credentials: "include"
            })
            .then(response => response.text())
            .catch(error => alert(error))
            .then(data => statusField.innerHTML = `${DEFAULT_DEBUG_TEXT} Slette ett dikt: ${data}`);
        }
        //if ID is empty
        else
            statusField.innerHTML = `${DEFAULT_DEBUG_TEXT}Diktid er ikke angitt - kan ikke slette dikt`;
        window.scrollTo(0, 0);

    }

    /*---------------DELETE ALL---------------*/
    else if(event.target && event.target.id == "delete_all") {


        const url="http://localhost:8000/cgi-bin/rest.sh/diktsamling/dikt/";
        fetch(url, {
            method: "DELETE",
            headers: {
                "Content-Type": "application/xml",
                "Accept": "application/xml"
            },
            credentials: "include"
        })
        .then(response => response.text())
        .catch(error => alert(error))
        .then(data => statusField.innerHTML = `${DEFAULT_DEBUG_TEXT} Slette alle dikt: ${data}`);
        
        window.scrollTo(0, 0);

    }

 });


//get poem
getPoem.elements.read_poem.addEventListener("click", event => {
    event.preventDefault();

    //get poem ID
    const poemId = getPoem.elements.diktid.value;


    //if no poem ID is presented
    if(poemId == "")
        statusField.innerHTML = `${DEFAULT_DEBUG_TEXT} Diktid er ikke angitt - kan ikke hente dikt`;

    //if valid input
    else {
        const url = `http://localhost:8000/cgi-bin/rest.sh/diktsamling/dikt/${poemId}`;

        fetch(url, {
            mehtod: "GET",
            headers: {
                "Content-Type": "application/xml", 
                "Accept": "application/xml"
            }    
        })
        .then(response => response.text())
        .catch(error => alert(error))
        .then(data => {
            //empy data length is 23
            if(data.length <= 23)
                statusField.innerHTML = `${DEFAULT_DEBUG_TEXT} Ingen dikt med id = ${poemId}`;
            else
                statusField.innerHTML = `${DEFAULT_DEBUG_TEXT} ${data}`;
        });
    }
    window.scrollTo(0, 0);

});

//gets all poems
getAll.elements.read_all.addEventListener("click", event => {  
    event.preventDefault();
    const url = "http://localhost:8000/cgi-bin/rest.sh/diktsamling/dikt/";

    fetch(url, {
        method: "GET",
        headers: {
            "Content-Type": "application/xml", 
            "Accept": "application/xml"
        },
        credentials: "include"

    })
    .then(response => response.text())
    .catch(error => alert(error))
    .then(data => {
        statusField.innerHTML = `${DEFAULT_DEBUG_TEXT} ${data}`;
    });
    window.scrollTo(0, 0);

});

//sets login environment
const setLoginEnv = username => {
    loginDiv.innerHTML = `<p>Du er logget inn som: ${username}</p>
    <FORM ACTION="" METHOD="POST" ID="logout-form">
    <INPUT TYPE="hidden" NAME="todo" VALUE="logout">
    <INPUT TYPE="submit" ID="logout" VALUE="Logg ut">
    </FORM>`;


    const postPoem = document.createElement("div");
    const putPoem = document.createElement("div");
    const deletePoem = document.createElement("div");
    const deleteAllPoems = document.createElement("div");


    postPoem.innerHTML = `<div class="form-div" id="create_div">
    <p>Lag nytt dikt</p>
    <FORM ACTION="" METHOD="POST", ID="create-poem">
    <INPUT TYPE="hidden" NAME="todo" VALUE="Post">
    <INPUT TYPE="text" NAME="dikttekst" VALUE="">
    <INPUT TYPE="submit" ID="create" VALUE="Lagre nytt dikt">
    </FORM>
    </div>`;

    putPoem.innerHTML = `<div class="form-div" id="update_div">
    <p>Rediger dikt</p>
    <FORM ACTION="" METHOD="POST" id="update-poem">
    <INPUT TYPE="hidden" NAME="todo" VALUE="Put">
    <label for="inp_diktid">Angi dikt-id</label>
    <INPUT TYPE="text" NAME="diktid" ID="inp_diktid" VALUE="">
    <label for="inp_dikttekst">Ny tekst</label>
    <INPUT TYPE="text" NAME="dikttekst" ID="inp_dikttekst" VALUE="">
    <INPUT TYPE="submit" ID="update" VALUE="Endre dikt">
    </FORM>
    </div>`;

    deletePoem.innerHTML = `<div class="form-div" id="delete_div">
    <p>Slett et dikt</p>
    <FORM ACTION="" ID="delete-poem" METHOD="POST">
    <INPUT TYPE="hidden" NAME="todo" VALUE="Delete">
    <label for="inp_diktid">Angi dikt-id</label>
    <INPUT TYPE="text" NAME="diktid" id="inp_diktid" VALUE="">
    <INPUT TYPE="submit" ID="delete" VALUE="Slett dikt">
    </FORM>
    </div>`;

    deleteAllPoems.innerHTML =     `<div class="form-div" id="delete_all_div">
    <p>Slett alle mine dikt</p>
    <FORM ACTION="" ID="delete-all-poems" METHOD="POST">
    <INPUT TYPE="hidden" NAME="todo" VALUE="Deleteall">
    <INPUT TYPE="submit" ID="delete_all" VALUE="Slett alle dikt">
    </FORM>
    </div>`;

    document.body.appendChild(postPoem);
    document.body.appendChild(putPoem);
    document.body.appendChild(deletePoem);
    document.body.appendChild(deleteAllPoems);


}

//sets logout environment
const setLogoutEnv = () => {
    
    loginDiv.innerHTML = `<p>Du må logge inn</p>
    <FORM ACTION="" ID="login-form" METHOD="POST">
    <INPUT TYPE="hidden" NAME="todo" VALUE="login">
    <label for="inp_user">Brukernavn</label>
    <INPUT TYPE="text" NAME="username" ID="inp_user" VALUE="">
    <label for="inp_password">Passord</label>
    <INPUT TYPE="password" NAME="password" ID="inp_password" VALUE="">
    <INPUT TYPE="submit" ID="login" VALUE="Logg inn">
    </FORM>`;
    const postPoem = document.querySelector("#create_div");
    const putPoem = document.querySelector("#update_div");
    const deletePoem = document.querySelector("#delete_div");
    const deleteAllPoems = document.querySelector("#delete_all_div");
    postPoem.remove();
    putPoem.remove();
    deletePoem.remove();
    deleteAllPoems.remove();


}