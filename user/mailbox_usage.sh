#!/usr/bin/env bash
# Author:  Oliver Ladner <oli@lugh.ch>
# License: LGPL
#
# Lists mailbox size of all virtual users
# of all domains

MAILDIR="/var/virtualmail"

PER_USER="$MAILDIR/*.*/*"
PER_DOMAIN="$MAILDIR/*.*/"
TOTAL="$MAILDIR"
TRASHDIR="$MAILDIR/*.*/*/Maildir/.Trash/*/"
SPAMDIR="$MAILDIR/*.*/*/Maildir/.Junk/*/"
DRAFTSDIR="$MAILDIR/*.*/*/Maildir/.Drafts/*/"
SENTDIR="$MAILDIR/*.*/*/Maildir/.Sent/*/"

echo "Per User"
du -hs $PER_USER | sort -rh | awk -F"/" '{print $1,$5,"@"$4}' | sed 's/ @/@/g'
echo -e "\r"

echo "Per Domain"
du -hs $PER_DOMAIN | sort -rh | awk -F"/" '{print $1,$4}'
echo -e "\r"

echo "Trash Folders"
du -hs $TRASHDIR | sort -rh | awk -F"/" '{print $1,$5,"@"$4}' | sed 's/ @/@/g' | grep -v "4.0K" | grep -v "8.0K"
echo -e "\r"

echo "Spam Folders"
du -hs $SPAMDIR | sort -rh | awk -F"/" '{print $1,$5,"@"$4}' | sed 's/ @/@/g' | grep -v "4.0K" | grep -v "8.0K"
echo -e "\r"

echo "Drafts Folders"
du -hs $DRAFTSDIR | sort -rh | awk -F"/" '{print $1,$5,"@"$4}' | sed 's/ @/@/g' | grep -v "4.0K" | grep -v "8.0K"
echo -e "\r"

echo "Sent Folders"
du -hs $SENTDIR | sort -rh | awk -F"/" '{print $1,$5,"@"$4}' | sed 's/ @/@/g' | grep -v "4.0K" | grep -v "8.0K"
echo -e "\r"

echo "Total"
du -hs $TOTAL
