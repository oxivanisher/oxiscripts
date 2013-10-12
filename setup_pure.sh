#!/bin/bash

# your email address
export ADMINMAIL=root@localhost

# where do you keep your own scripts
export SCRIPTSDIR=$HOME/scripts



# your backup mountpoint
export BACKUPDIR=/mnt/backup/

# your mail command
export MAILCOMMAND=$( which mailx 2>/dev/null )



# should the output be colorful? (0/1)
export OXICOLOR=1

# generate debug output (0/1)
export DEBUG=0

# the mirror for update
export OXIMIRROR=http://www.mittelerde.ch/install.sh

# do not change the release number
export OXIRELEASE=xxx
