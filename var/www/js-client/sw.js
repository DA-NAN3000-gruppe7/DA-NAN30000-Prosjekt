const appCache = "gruppe7_app-cache";

let GET_ALL_REQUEST;



//add the files to the cache
self.addEventListener("install", event => {
    event.waitUntil(
      caches.open(appCache)
      .then(cache => {
        return cache.addAll(
          [
            "/favicon.ico",
            "/index.html",
            "/css/style.css",
            "/img/html5.png",
            "/js-client/app.js",
            "/js-client/index.html",
            "/js-client/style.css"
          ]
        )
      })
      .catch(error => console.log(error))
    );
});

//activates the service worker
self.addEventListener("activate", event => event.waitUntil(clients.claim()));

//caches requests and responses
self.addEventListener('fetch', event => {
  //assigns the GET_ALL request

  //caches all the GET requests
  if(event.request.url == "http://localhost:8000/cgi-bin/rest.py/diktsamling/dikt/" && event.request.method == "GET")
    mapAllGetRequests(event.request)

  event.respondWith(caches.match(event.request)
  .then(resp => resp || fetch(event.request))
  .then(response => {
    let responseClone = response.clone();
    caches.open('gruppe7_app-cache')
    .then(cache => cache.put(event.request, responseClone));

    return response;
  })
  .catch(error => console.log(error))
  )
});


//maps all the GET requests to cache
const mapAllGetRequests = request => {
  let poemIdList = [];
  fetch(request)
  .then(response => response.text())
  .then(xml_text => {
    let poemList = xml_text.split("<diktID>")
    poemList.shift();
    
    let poemIdList = [];
    for(i in poemList) {
      let url = `http://localhost:8000/cgi-bin/rest.py/diktsamling/dikt/${poemList[i].split("</diktID>", 1)[0]}`;

      const request = new Request(url, {
        mehtod: "GET",
        headers: {
            "Content-Type": "application/xml", 
            "Accept": "application/xml"
        }
      })
      fetch(request)
      .then(response => {
        let responseClone = response.clone();
        caches.open('gruppe7_app-cache')
        .then(cache => cache.put(request, responseClone))
      .catch(error => console.log(error))
      });
    }
  });
}