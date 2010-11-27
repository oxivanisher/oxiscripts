#!/bin/bash
. /etc/oxiscripts/functions.sh

#This job cleans the .deb cache
SIZEBEFORE=$(du -sh /var/cache/apt/archives | awk '{print $1}')
find /var/cache/apt/archives/* -type f -delete 2>&1
SIZEAFTER=$(du -sh /var/cache/apt/archives | awk '{print $1}')

if [ $SIZEBEFORE != $SIZEAFTER ];
then
	ox-base-notifyadmin "APT Cache cleaner on $(hostname)" "Size before: $SIZEBEFORE\nSize after: $SIZEAFTER"
fi
