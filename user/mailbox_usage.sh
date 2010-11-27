#!/bin/sh
# $Id: mailbox_usage.sh 11 2009-02-06 08:48:41Z oli $
#
# Lists mailbox size of all virtual users
# of all domains

MAIL_DIR="/var/vmail/*.*/*"

du -sk $MAIL_DIR | sort -rn | awk '{print $2}' | xargs -ia du -hs "a" | awk -F"/" '{print $1,$5,"@"$4}' | sed 's/ @/@/g'
