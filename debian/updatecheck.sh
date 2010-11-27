#!/bin/bash
. /etc/oxiscripts/functions.sh

/usr/bin/apt-get update >/dev/null

if [ "$(/usr/bin/apt-get -d -s -q upgrade | grep "upgraded,")" != "0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded." ];
then
	ox-base-notifyadmin "APT Update Status on $(hostname)" "$(/usr/bin/apt-get upgrade -q -d -s)"
fi
