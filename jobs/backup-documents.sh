#!/bin/bash
. /etc/oxiscripts/backup.sh

#Choose which dirs may be in your SRC Dir. Please add ONLY the ones you need.
#EXCLUDED_DIR="/bin /boot /dev /lib /lost+found /mnt /opt /proc /sbin /sys /tmp /usr"
EXCLUDED_DIR=""

#Set rdiff-backup dirs here:
#rdiffbackup SRC-DIR FABRIC REMOVE-OLDER-THAN

#example:
#rdiffbackup /var/www apache 6M
