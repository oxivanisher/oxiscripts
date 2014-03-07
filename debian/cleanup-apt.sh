#!/bin/bash
. /etc/oxiscripts/functions.sh

#This job cleans the .deb cache
SIZEBEFORE=$(du -sh /var/cache/apt/archives | awk '{print $1}')
apt-get clean
SIZEAFTER=$(du -sh /var/cache/apt/archives | awk '{print $1}')

#if [ $SIZEBEFORE != $SIZEAFTER ];
if [ $DEBUG -gt 0 ]; 
then
	ox-base-notifyadmin "APT Cache cleaner on $(hostname)" "Size before: $SIZEBEFORE\nSize after: $SIZEAFTER"
fi
