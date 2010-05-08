#!/bin/bash
. /etc/oxiscripts/setup.sh

/usr/bin/apt-get update >/dev/null

if [ "$(/usr/bin/apt-get -d -s -q upgrade | grep "upgraded,")" != "0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded." ];
then
	notifyadmin "APT Update Status on $(hostname)" "$(/usr/bin/apt-get upgrade -q -d -s)"
fi
