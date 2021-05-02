#!/bin/bash

#checking if root is running
if [ "$EUID" -ne 0 ]
  then echo "Server must be run as root. Use 'sudo ./run.sh' next time"
  exit
fi

#assings path to current directory and to init.sh
ROTFS=$PWD/unshare
INIT=$ROTFS/bin/init.sh


#if dumb-init is not in bin, download it
if [ ! -f $ROTFS/bin/dumb-init ];then
	 wget -O $ROTFS/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.5/dumb-init_1.2.5_x86_64
	 chmod +x $ROTFS/bin/dumb-init
fi
#if there are no busybox sym-links, create them
if [[ -z $(find $ROTFS/bin -type l -ls) ]];then
	cd $ROTFS/bin/
	cp /bin/busybox .

	for P in $(./busybox --list); do 
		ln -s busybox $P; 
	done
fi



#compile the webserver.c code
#adding a condition so that the server doesn't run if webserver.c failed compiling
if gcc $ROTFS/bin/webserver.c --static -o $ROTFS/bin/webserver.o; then
	chown root:root $ROTFS/bin/webserver.o
	chmod u+s $ROTFS/bin/webserver.o


	#starting docker containers

	cd $PWD/docker


	# starting docker containers
	sudo useradd dockremapper # Oppretter bruker
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
	docker cp rest.sh  REST_API:/usr/local/apache2/cgi-bin
	docker cp editor.sh  WEB_INTERFACE:/usr/local/apache2/cgi-bin

	docker cp httpd.conf  REST_API:/usr/local/apache2/conf
	docker cp httpd.conf  WEB_INTERFACE:/usr/local/apache2/conf


	cd $ROTFS
	#mount /proc as proc in current directory
	mount -t proc proc $ROTFS/proc

	#create new namespace and change root, executing init.sh
	PATH=/bin unshare -p -f --mount-proc=$ROTFS/proc /usr/sbin/chroot . /bin/init.sh

	#unmounting the namespace
	umount $ROTFS/proc

	#stoping docker containers
	docker container stop WEB_INTERFACE
	docker container stop REST_API
	docker container rm WEB_INTERFACE
	docker container rm REST_API
fi