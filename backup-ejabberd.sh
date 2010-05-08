#!/bin/bash
. /etc/oxiscripts/backup.sh

#This job exports and backups the ejabberd database
#The config file should be backuped automatically by backup-system.sh
/usr/sbin/ejabberdctl backup /tmp/ejabberd.backup
backup /tmp/ejabberd.backup ejabberd
rm /tmp/ejabberd.backup
