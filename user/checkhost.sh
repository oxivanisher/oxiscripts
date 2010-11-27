#!/bin/bash

. /etc/oxiscripts/init.sh

SLEEPTIME=1
TARGETHOST=localhostxx

BOOL=true

while $BOOL;
do
	ping -c1 $TARGETHOST 

	if [[ "$?" -eq "0" ]];
	then
		sleep $SLEEPTIME
	else
		echo "Host went down at `date`" | mailx -s "chechhost.sh watch" $ADMINMAIL
		BOOL=false	
	fi
done
