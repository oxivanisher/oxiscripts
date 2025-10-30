#!/bin/bash
#$( echo $0 | sed s/$(basename $0)//g )
source /etc/oxiscripts/setup.sh
TIMESTAMP=$(date +%Y%m%d%H%M%S)

rdiffbackup () {
	LOGFILE="${LOGDIR}/rdiffbackup.log"
	echo "Rdiffbackup starting at $(date) for $1 to $2 with parameters: $3" >> ${LOGFILE}

	mountbackup
	FOLDERNAME="/$BACKUPDIR/oxirdiffbackup/$(hostname)/$2/"

	CHOWNO=$(chmod 777 $FOLDERNAME)

	MKDIRO=$(mkdir -p $FOLDERNAME 2>&1)

	PARAMETER=""
	for DIR in ${EXCLUDED_DIR}; do
	PARAMETER="$PARAMETER--exclude $DIR "
	done


	$(which rdiff-backup) backup $PARAMETER $1 $FOLDERNAME &>>${LOGFILE}
	$(which rdiff-backup) --force remove increments --older-than $3 $FOLDERNAME &>>${LOGFILE}


	SIZEF=$(du -sh $BACKUPDIR/oxirdiffbackup/$(hostname)/$2)
	SIZEH=$(du -sh $BACKUPDIR/oxirdiffbackup/$(hostname)/)
	SIZET=$(du -sh $BACKUPDIR/oxirdiffbackup/)

	NEWLISTING=$(ls -lha $BACKUPDIR/oxirdiffbackup/$(hostname)/$2/)
	MOUNT=$(mount | grep $BACKUPDIR 2>&1)

	umountbackup

	if [ -n "$MOUNT" ]; then
		MOUNT="mount:\t$MOUNT\n"
	fi

	if [ -n "$MOUNTO" ]; then
		MOUNTO="mount:\t$MOUNTO\n"
	fi

	if [ -n "$UMOUNTO" ]; then
		UMOUNTO="mount:\t$UMOUNTO\n"
	fi

	if [ -n "$MKDIRO" ]; then
		MKDIRO="mount:\t$MKDIRO\n"
	fi

	SIZE="size total:\t$SIZET\nsize host:\t$SIZEH\nsize fabric:\t$SIZEF"

	MESSAGE="-- FILES IN $FOLDERNAME --\n$NEWLISTING\n\n-- SIZE INFOS --\n$SIZE\n\n-- DEBUG INFOS --\n$MOUNT$RDIFF1O\n$RDIFF2O\n$MOUNTO$UMOUNTO$MKDIRO\n$CHOWNO"

	echo -e "Rdiffbackup finished.\n" >> ${LOGFILE}
	if [ $DEBUG -gt 0 ]; then
		notifyadmin "$(hostname) $2 rdiff-backup" "${MESSAGE}"
	fi
}


backup () {
	LOGFILE="${LOGDIR}/backup.log"
	echo "Backup starting at $(date) for $1 to $2 with options: $3" >> ${LOGFILE}

	mountbackup
	FILENAME="/$BACKUPDIR/oxibackup/$(hostname)/$2/$(date +%Y%m)/$(basename $1).$TIMESTAMP.tar.bz2"

	MKDIRO=$(mkdir -p $BACKUPDIR/oxibackup/$(hostname)/$2/$(date +%Y%m) 2>&1)
	TARO=$(/bin/tar ${BACKUP_OPTIONS} -cjf $FILENAME $1 &>>${LOGFILE})

	SIZEF=$(du -sh $BACKUPDIR/oxibackup/$(hostname)/$2)
	SIZEH=$(du -sh $BACKUPDIR/oxibackup/$(hostname)/)
	SIZET=$(du -sh $BACKUPDIR/oxibackup/)

	NEWLISTING=$(ls -lha $BACKUPDIR/oxibackup/$(hostname)/$2/$(date +%Y%m))
	MOUNT=$(mount | grep $BACKUPDIR 2>&1)

	umountbackup

	if [ -n "$MOUNT" ]; then
	MOUNT="mount:\t$MOUNT\n"
	fi

	if [ -n "$MOUNTO" ]; then
	MOUNTO="mount:\t$MOUNTO\n"
	fi

	if [ -n "$UMOUNTO" ]; then
	UMOUNTO="mount:\t$UMOUNTO\n"
	fi

	if [ -n "$TARO" ]; then
	TARO="tar:\t$TARO\n"
	fi

	if [ -n "$MKDIRO" ]; then
	MKDIRO="mount:\t$MKDIRO\n"
	fi

	SIZE="size total:\t$SIZET\nsize host:\t$SIZEH\nsize fabric:\t$SIZEF"

	MESSAGE="-- FILES IN $BACKUPDIR/oxibackup/$(hostname)/$2/$(date +%Y%m) --\n$NEWLISTING\n\n-- SIZE INFOS --\n$SIZE\n\n-- DEBUG INFOS --\n$MOUNT$TARO$MOUNTO$UMOUNTO$MKDIRO"

	echo -e "${MESSAGE}\nBackup finished.\n" >> ${LOGFILE}
	if [ $DEBUG -gt 0 ]; then
		notifyadmin "$(hostname) $2 backup" "${MESSAGE}"
	fi
}

rsyncbackup () {
	LOGFILE="${LOGDIR}/rsyncbackup.log"
	LOCKFILE="/var/run/oxiscripts-rsyncbackup.pid"
	while $(test -f "${LOCKFILE}"); do sleep 10; done
	echo $$ > "${LOCKFILE}"
	echo "Rsyncbackup starting at $(date) for $1 to $2 with options: $3 ${PARAMETER}" >> ${LOGFILE}

	PARAMETER=""
	for DIR in ${EXCLUDED_DIR}; do
		PARAMETER="$PARAMETER--exclude $DIR "
	done


	trap "rm -f ${LOCKFILE}" SIGHUP SIGINT SIGTERM
	if [ -z "$RSYNCPASSWORD" ]; then
		RSYNCO=$($(which rsync) -avh --no-g $3 --log-file=${LOGFILE} ${PARAMETER} $1 $2)
	else
		echo "$RSYNCPASSWORD" > /etc/oxiscripts/rsyncpw-$$.tmp
		chmod 600 /etc/oxiscripts/rsyncpw-$$.tmp
		#RSYNCO=
		RSYNCO=$($(which rsync) -avh --no-g $3 --password-file=/etc/oxiscripts/rsyncpw-$$.tmp --log-file=${LOGFILE} ${PARAMETER} $1 $2)
		rm /etc/oxiscripts/rsyncpw-$$.tmp
	fi

	echo -e "Rsyncbackup finished.\n" >> ${LOGFILE}
	if [ $DEBUG -gt 0 ]; then
		notifyadmin "$(hostname) $2 rsync-backup" "-- DEBUG INFOS --\n$RSYNCO"
	fi
	rm -f "${LOCKFILE}"
}


backupinfo () {
	mountbackup

	SIZET="size total:\t$(du -sh $BACKUPDIR/oxibackup/)"
	SIZEH="size host:\t$(du -sh $BACKUPDIR/oxibackup/$(hostname)/)"

	SIZEF="## size of oxibackup\n"
	for FABRIC in $(ls $BACKUPDIR/oxibackup/$(hostname)/); do
		SIZEF="${SIZEF}### $BACKUPDIR/oxibackup/$(hostname)/$FABRIC\n$(du -sh $BACKUPDIR/oxibackup/$(hostname)/$FABRIC| awk '{print $1}') total\n"
		for MONTH in $(ls $BACKUPDIR/oxibackup/$(hostname)/$FABRIC); do
			SIZEF="$SIZEF$(du -sh $BACKUPDIR/oxibackup/$(hostname)/$FABRIC/$MONTH | awk '{print $1}')\t\t$MONTH\n"
		done
		SIZEF="$SIZEF\n"
	done

	if [ -d $BACKUPDIR/oxirdiffbackup/$(hostname)/ ]; then
		if [ $BACKUPINFORDIFF -gt 0 ]; then
			SIZEF="${SIZEF}## size of oxirdiffbackup\n"
			for FABRIC in $(ls $BACKUPDIR/oxirdiffbackup/$(hostname)/); do
				SIZEF="$SIZEF$(du -sh $BACKUPDIR/oxirdiffbackup/$(hostname)/$FABRIC)\n"
				# This is creating a LOT of disk usage ... disabling it for now
				# for FOLDER in $(ls $BACKUPDIR/oxirdiffbackup/$(hostname)/$FABRIC); do
				# 	SIZEF="$SIZEF$(du -sh $BACKUPDIR/oxirdiffbackup/$(hostname)/$FABRIC/$FOLDER | awk '{print $1}')\t\t$FOLDER\n"
				# done
				# SIZEF="$SIZEF\n"
			done
		else
			SIZEF="${SIZEF}## not analyzing oxirdiffbackups because backupinfordiff is disabled\n\n"
		fi
	fi

	notifyadmin "$(hostname) backup info (uptime: $(uptime))" "# $(hostname) backup usage\n$SIZET\n$SIZEH\n\n# fabrics\n$SIZEF"

	umountbackup
}

backupcleanup () {
	mountbackup

	if [ -n $(which fdupes) ]; then
		SIZEBEFORE=$(du -sh $BACKUPDIR/oxibackup/$(hostname))
		COUNT=0
		for FILE in $(fdupes -r -f -q $BACKUPDIR/oxibackup/$(hostname)); do
			COUNT=$(($COUNT+1))
			rm $FILE
		done

		if [[ $1 =~ ^-?[0-9]+$ ]]; then
			find "$BACKUPDIR/oxibackup/$(hostname)" -type f -mtime +$1 -exec rm {} \;

			find "$BACKUPDIR/oxibackup/$(hostname)" -type d | while read LINE;
			do
			        if [ $(find "$LINE" -type f | wc -l) == 0 ];
			        then
			                rmdir "$LINE" > /dev/null 2>&1
			        fi
			done
		fi

		SIZEAFTER=$(du -sh $BACKUPDIR/oxibackup/$(hostname))

		if [ $DEBUG -gt 0 ]; then
			notifyadmin "$(hostname) backup cleanup" "# $(hostname) backup cleanup\n\nfiles cleaned:\t$COUNT\nsize before:\t$SIZEBEFORE\nsize after:\t$SIZEAFTER"
		fi
	else
		nofityadmin "backup cleanup FAIL" "please install fdupes!"
	fi

	umountbackup
}
