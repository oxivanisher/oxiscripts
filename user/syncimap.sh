#!/bin/bash

logfile="synclog.txt"

host1=85.90.1.13
#host1 is Source

host2=172.16.25.130
#host2 is Dest

domain=acceleris.ch
#domain is where email account is
#everything after @ symbol

###### Do not modify past here
#######################################

date=`date +%X_-_%x`

grep -v "#" imapsync.csv > /tmp/imapsync.tmp

echo "" >> $logfile
echo "------------------------------------" >> $logfile
echo "IMAPSync started.. $date" >> $logfile
echo "" >> $logfile

{ while IFS=';' read u1 p1; do
user=$u1"@"$domain
echo "Syncing User $user"
date=`date +%X_-_%x`
echo "Start Syncing User $u1"
echo "Starting $u1 $date" >> $logfile
imapsync --buffersize 8192000 --nosyncacls --syncinternaldates --host1 $host1 --user1 "$user" --password1 \
"$p1" --host2 $host2 --user2 "$user" --password2 "$p1" --noauthmd5 --ssl2 --port2 993
date=`date +%X_-_%x`
echo "User $user done"
echo "Finished $user $date" >> $logfile
echo "" >> $logfile

done ; } < /tmp/imapsync.tmp

date=`date +%X_-_%x`

echo "" >> $logfile
echo "IMAPSync Finished.. $date" >> $logfile
echo "------------------------------------" >> $logfile
