#!/bin/bash
. /etc/oxiscripts/backup.sh

#This job backups the scripts directory of each user
if [ -d /root/scripts ]; then
	backup /root/scripts root-scripts
fi

if [ -d /home/*/scripts ]; then
	backup /home/*/scripts user-scripts
fi

#This job backups the bin directory of each user
if [ -d /root/bin ]; then
	backup /root/bin root-bin
fi

if [ -d /home/*/bin ]; then
	backup /home/*/bin user-bin
fi
