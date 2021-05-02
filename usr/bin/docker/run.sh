#!/bin/bash

# checking if root is running
if [ "$EUID" -ne 0 ]
  then echo "Server must be run as root. Use 'sudo ./run.sh' next time"
  exit
fi

# assings path to current directory and to init.sh
ROTFS=$PWD

# starting docker containers
sudo adduser dockremapper # Oppretter bruker
sudo dockerd --userns-remap=default & # remapper bruker
##
## Dette starter docker med dockermap user og group opprettes og mappes mot ikke-priviligerte uid og gid - "ranges" i /etc/subuid og /etc/subgid - filene.
##

# Starter docker service
systemctl start docker.service
docker login

# Henter image
docker pull hkulterud/dockerhub:g7mp3_image

# Create containers
docker container run -d --cap-drop=setfcap --cpu-shares 512 -m 512m -it -p 8000:80 --name REST_API hkulterud/dockerhub:g7mp3_image
docker container run -d --cap-drop=setfcap --cpu-shares 512 -m 512m -it -p 8080:80 --name WEB_INTERFACE hkulterud/dockerhub:g7mp3_image
## 
## Containere kjører med 512 cpu-shares og limit på 512MB ram (cgroups), samt dropper capabilities setfcap
## Her kan man kjøre --cap-drop=all når man er ferdig å jobbe i containeren

# Eventuelt kopiere filer
docker cp rest.sh  g7alpine1:/usr/local/apache2/cgi-bin
docker cp editor.sh  g7alpine2:/usr/local/apache2/cgi-bin

docker cp httpd.conf  g7alpine1:/usr/local/apache2/conf
docker cp httpd.conf  g7alpine2:/usr/local/apache2/conf

# Sette rettigheter hvis det ikke er gjort allerede
# chmod 755 cgi-bin/editor.sh
# chmod 755 cgi-bin/rest.sh