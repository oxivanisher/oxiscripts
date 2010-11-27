#!/bin/bash

HOST="edoras.mittelerde.ch"
KEY="$HOME/.ssh/rsync_key"
USER="oxi"
BASEDIR="rsync"


HOSTNAME=`hostname`
#sleep 5

# attention! everything must be in yout HOME dir!
BACKUPDIRS="scripts"
SYNCDIRS=".tomboy .gaim/logs"


echo backup and sync script by oxi

echo "backuping [/etc]"
ssh -i $KEY $USER@$HOST mkdir -p $BASEDIR/$HOSTNAME/etc
rsync -zruc --log-file=/dev/null -e "ssh -i $KEY" /etc/ $USER@$HOST:~/$BASEDIR/$HOSTNAME/etc/ 2>&1 >/dev/null


function backupdir {
	echo "backuping [~/$1]"
	ssh -i $KEY $USER@$HOST mkdir -p $BASEDIR/$HOSTNAME/$1
	rsync -zruc -e "ssh -i $KEY" ~/$1/ $USER@$HOST:~/$BASEDIR/$HOSTNAME/$1/
}


function syncdir {
	echo "synchronizing [~/$1]"
	ssh -i $KEY $USER@$HOST mkdir -p $BASEDIR/$1
	rsync -zruc -e "ssh -i $KEY" $USER@$HOST:~/$BASEDIR/$1/ ~/$1/
	rsync -zruc -e "ssh -i $KEY" ~/$1/ $USER@$HOST:~/$BASEDIR/$1/
}


for MYDIR in ${BACKUPDIRS}
do
	backupdir $MYDIR
done

for MYDIR in ${SYNCDIRS}
do
	syncdir $MYDIR
done

