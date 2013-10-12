#!/bin/bash
. /etc/oxiscripts/backup.sh

#This job exports and backups the mysql database
/usr/bin/mysqldump --opt --all-databases > /tmp/mysql-backup.sql
backup /tmp/mysql-backup.sql mysql
rm /tmp/mysql-backup.sql
