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
