#!/bin/bash
. /etc/oxiscripts/functions.sh

/usr/bin/apt-get update >/dev/null

if [ "a$(/usr/bin/apt-get -d -s -q upgrade | grep 'upgraded,' | grep -v '0 upgraded, 0 newly installed, 0 to remove and')" != "a" ];
then
	ox-base-notifyadmin "APT Update Status on $(hostname)" "$(/usr/bin/apt-get upgrade -q -d -s)"
fi
