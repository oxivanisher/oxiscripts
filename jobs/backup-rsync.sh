#!/bin/bash
. /etc/oxiscripts/backup.sh

EXCLUDED_DIR="lost+found"

# Pass the password via the RSYNC_PASSWORD environment variable, which rsync
# reads natively. Set it as a prefix on the rsyncbackup call, e.g.:
#   RSYNC_PASSWORD="secret" rsyncbackup /mnt/backup rsync://backup@your.host.com/rsync-dir "--bwlimit=1000"

rsyncbackup /mnt/backup rsync://backup@your.host.com/rsync-dir "--bwlimit=1000"

# the 3rd option is for passing options through to rsync
