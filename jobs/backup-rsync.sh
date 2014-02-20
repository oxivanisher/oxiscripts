#!/bin/bash
. /etc/oxiscripts/backup.sh

RSYNCPASSWORD="secret"
EXCLUDED_DIR="lost+found"

rsyncbackup /mnt/backup rsync://backup@your.host.com/rsync-dir "--bwlimit=1000"

#the 3rd option is for passing options trough to rsync

#if you use this feature to backup your files from /mnt/backup to somewhere else,
#check the option to "remove older files than" in backup-cleanup.sh

#For no password:
RSYNCPASSWORD=""
