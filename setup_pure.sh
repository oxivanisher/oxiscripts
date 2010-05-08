#!/bin/bash

#setup some vars!
export ADMINMAIL=root@yournet.com
export BACKUPDIR=/mnt/backup/
export DEBUG=0
export SCRIPTSDIR=$HOME/scripts
export OXIMIRROR=http://www.mittelerde.ch/install.sh




export OXIRELEASE=xxx
export MAILCOMMAND=$(which mailx)

function mountbackup {
    while $(test -f /var/run/oxiscripts-backup.pid); do sleep 10; done
    echo $$ > /var/run/oxiscripts-backup.pid
    
    # please set your mount options
    # examples:
    # NFS	MOUNTO=$(mount -t nfs 192.168.1.1:/path/to/backup $BACKUPDIR 2>&1) 
    # FOLDER	MOUNTO=""
    # VBOX SF   MOUNTO=$(mount.vboxsf backup $BACKUPDIR 2>&1)
    MOUNTO=""
}

function umountbackup {

    # please set your umount options
    # examples:
    # NFS	MOUNTO=$(umount $BACKUPDIR 2>&1) 
    # FOLDER	MOUNTO=""
    UMOUNTO=""
    rm /var/run/oxiscripts-backup.pid
}


function notifyadmin {
    if [ "$0" = "-bash" ]; then
	SOURCE="Console"
    else
	SOURCE="$(basename $0)"
    fi
    echo -e "$2" | $MAILCOMMAND -s "$1 ($SOURCE)" $ADMINMAIL
}

function showrelease {
	echo -e "oXiScripts Release: $OXIRELEASE ($(echo $OXIRELEASE|awk '{print strftime("%c", $1)}'))"
}
