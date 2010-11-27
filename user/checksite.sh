#!/bin/bash

MYSITE=$1
SLEEP=10


CHECKME=true
MYDATA=`curl -s $MYSITE`

while "$CHECKME";
do
	MYCHECK=`curl -s $MYSITE`
	if [ "$MYDATA" != "$MYCHECK" ];
	then
		CHECKME=false
		xmessage -center "Site $MYSITE changed!"
	else
		echo "`date`: no changes so far ..."
		sleep $SLEEP
	fi
done
