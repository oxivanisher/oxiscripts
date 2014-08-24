#!/bin/bash
. /etc/oxiscripts/backup.sh

#This job backups the scripts directory of each user
if [ -d /root/scripts ]; then
	backup /root/scripts root-scripts
fi

if ls /home/*/scripts &> /dev/null; then
	backup /home/*/scripts user-scripts
fi

#This job backups the bin directory of each user
if [ -d /root/bin ]; then
	backup /root/bin root-bin
fi

if ls /home/*/bin &> /dev/null; then
	backup /home/*/bin user-bin
fi

#This job backups the .bash* file of each user
if ls /root/.bash* &> /dev/null; then
	for FILE in /root/.bash*;
	do
		backup $FILE root-bash
	done
fi

for DIR in /home/*;
do
	for FILE in $DIR/.bash*;
	do
		backup $FILE user-$(basename $DIR)-bash
	done
done
