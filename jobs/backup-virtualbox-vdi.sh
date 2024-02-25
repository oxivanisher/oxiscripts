#!/bin/bash
. /etc/oxiscripts/backup.sh

#Please add your executes AFTER the function!
backupvdi () {
    while $(test -f /var/run/oxiscripts-vdibackup.pid); do sleep 10; done
    echo $$ > /var/run/oxiscripts-vdibackup.pid

	PARAMETER=""
	RUNNINGTEST=$(ps -o "%a"  $(lsof | grep $(echo "$1" | sed 's/*//g') | awk '{print $2}' | uniq) | tail -n 1 | awk '{print $3}')
	RUNNING=$RUNNINGTEST

	mkdir -p $BACKUPDIR/oxibackupvdi/$(hostname)/$2
#	mkdir -p $BACKUPDIR/oxibackupvdi/$(hostname)/$2.sav/

#	rm $BACKUPDIR/oxibackupvdi/$(hostname)/$2.sav/*
	#Backup the Backup ..
#	VDIBACKUPO="=> Moving the Backup $BACKUPDIR/oxibackupvdi/$(hostname)\n"
#	VDIBACKUPO=$VDIBACKUPO$($mv -u $BACKUPDIR/oxibackupvdi/$(hostname)/$2/* $BACKUPDIR/oxibackupvdi/$(hostname)/$2.sav/)

	#FIXME shutdown if machine is running
	if [ -n "$RUNNING" ]; then
		beep -f 800 && beep -f 400
		su $VDIUSER -c "$(which screen) -dmS bye-$2 VBoxManage controlvm $RUNNING acpipowerbutton"
		VDIBACKUPO="$VDIBACKUPO\n=> Sleeping while VM shutdown"
		sleep 20
	fi

	#Backup the Source ...
	VDIBACKUPO="$VDIBACKUPO\n=> Backuping the Source $1"
    VDIBACKUPO=$VDIBACKUPO\n$(cp -v $1 $BACKUPDIR/oxibackupvdi/$(hostname)/$2/)

	#FIXME restart the VM
	if [ -n "$RUNNING" ]; then
		beep -f 400 && beep -f 800
		su $VDIUSER -c "$( which screen 2>/dev/null ) -dmS $RUNNING $( which VBoxHeadless 2>/dev/null ) -s $RUNNING"
	fi

    if [ $DEBUG -gt 0 ]; then
        ox-base-notifyadmin "$(hostname) $2 vdi-backup" "-- DEBUG INFOS --\n$VDIBACKUPO"
    fi
    rm /var/run/oxiscripts-vdibackup.pid
}

#set -x

#Important settings!
VDIUSER=

#It is very important that you use "" in case of multiple files/dirs. example: backupvdi "/var/www/www." /path/to/backup
backupvdi "/home/$VDIUSER/.VirtualBox/HardDisks/host_a_*" vdi-hosta
backupvdi /home/$VDIUSER/.VirtualBox/HardDisks/host_b.vdi vdi-hstb

#set +x
