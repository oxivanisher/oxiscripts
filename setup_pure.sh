#!/bin/bash

# your email address
export ADMINMAIL=root@localhost

# where do you keep your own scripts
export SCRIPTSDIR=$HOME/scripts



# your backup mountpoint
export BACKUPDIR=/mnt/backup/

# disable rsyncbackup info creation (0/1)
export BACKUPINFORDIFF=1

# your mail command
export MAILCOMMAND=$( which mailx 2>/dev/null )



# should the output be colorful? (0/1)
export OXICOLOR=1

# generate debug output (0/1)
export DEBUG=0

# the mirror for update
export OXIMIRROR=https://oxi.ch/files/install.sh

# do not change the release number
export OXIRELEASE=xxx

# internal vars
LOGDIR="/var/log/oxiscripts/"

mountbackup () {
    exec 9>/var/run/oxiscripts-backup.lock
    flock -x 9
    echo $$ >&9

    # please set your mount options
    # examples:
    # NFS	MOUNTO=$(mount -t nfs 192.168.1.1:/path/to/backup $BACKUPDIR 2>&1)
    # FOLDER	MOUNTO=""
    MOUNTO=""
}

umountbackup () {

    # please set your umount options
    # examples:
    # NFS	UMOUNTO=$(umount $BACKUPDIR 2>&1)
    # FOLDER	UMOUNTO=""
    UMOUNTO=""
    flock -u 9
    exec 9>&-
}


notifyadmin () {
    if [ "$0" = "-bash" ]; then
	SOURCE="Console"
    else
	SOURCE="$(basename $0)"
    fi
    echo -e "$2" | $MAILCOMMAND -s "$1 ($SOURCE)" $ADMINMAIL
}

showrelease () {
	echo -e "oXiScripts Release: $OXIRELEASE ($(echo $OXIRELEASE|awk '{print strftime("%c", $1)}'))"
}
