#!/bin/bash
. /etc/oxiscripts/backup.sh

#If we are on a debian based system, backup the installed packages
if [ -n "$(which dpkg)" ]; then
	/usr/bin/dpkg --get-selections > /tmp/dpkg-selections
	backup /tmp/dpkg-selections system
	rm /tmp/dpkg-selections
fi

#Backup the entire /etc .. like magic ;)
backup /etc system


