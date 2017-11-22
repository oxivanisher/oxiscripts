#!/bin/bash
. /etc/oxiscripts/backup.sh

EJABBERDCTL=false

#This job exports and backups the ejabberd database
#The config file should be backuped automatically by backup-system.sh
if [ -f /usr/sbin/ejabberdctl ];
then
	# ejabberdctl from the debian package was used
	EJABBERDCTL=/usr/sbin/ejabberdctl
else
	# search for ejabberdctl by looking at running processes
	EJABBERDCTL="$(dirname $(ps -ef | grep ejabberd | grep epmd | awk '{print $8}'))/ejabberdctl"

	if [ "a$EJABBERDCTL" != "a" ];
	then
		# still nothing, so search for ejabberdctl in /opt for installer based setups
		EJABBERDCTL=$(find /opt -name ejabberdctl -type f -executable -print | head -n 1)
	fi
fi

if [ "a$EJABBERDCTL" != "a" ];
then
	$EJABBERDCTL backup /tmp/ejabberd.backup
	backup /tmp/ejabberd.backup ejabberd
	rm /tmp/ejabberd.backup
else
	notifyadmin "Unable to backup ejabberd since ejabberdctl could not be found"
fi
