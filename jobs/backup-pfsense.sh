#!/bin/bash
. /etc/oxiscripts/backup.sh

USER=admin
PASSWORD=pfsense
TARGETNAME="pfsense-config-$(date +%Y%m%d-%H%M%S).xml"
PFSENSE="https://10.X.10.1"

# script start
curl -s --insecure -o /tmp/$TARGETNAME -H "Expect:" -F Submit=download -u $USER:"$PASSWORD" $PFSENSE/diag_backup.php
backup /tmp/$TARGETNAME pfsense
rm /tmp/$TARGETNAME
