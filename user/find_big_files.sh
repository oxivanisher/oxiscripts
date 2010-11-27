#!/bin/sh
# $Id: find_big_files.sh 11 2009-02-06 08:48:41Z oli $
#
# Find and report big files

MIN_SIZE="$1M"
DIRS="/usr /home /etc /bin /var /sbin /tmp"
EXCLUDE=""

# df
DF=$(df -h)

if [ ! $1 ]; then
        echo "Usage: $0 <number-in-mb>"
        exit 1
else
        DO_IT=`find $DIRS -size +$MIN_SIZE -print -exec ls -lha {} \; | grep -v '$EXCLUDE' | awk {'print $5"\t"$6" "$7" "$8'}`
        LOL=`echo $DO_IT | wc -l`
        if [ "$LOL" -gt "0" ]; then
                echo $DO_IT
        fi
fi

