#!/bin/bash
#$( echo $0 | sed s/$(basename $0)//g )
. /etc/oxiscripts/setup.sh
TIMESTAMP=$(date +%Y%m%d%H%M%S)

function rdiffbackup {
    mountbackup
    FOLDERNAME="/$BACKUPDIR/oxirdiffbackup/$(hostname)/$2/"

    CHOWNO=$(chmod 777 $FOLDERNAME)

    MKDIRO=$(mkdir -p $FOLDERNAME 2>&1)

    PARAMETER=""
    for DIR in ${EXCLUDED_DIR}; do
	PARAMETER="$PARAMETER--exclude $DIR "
    done


    RDIFF1O=$($(which rdiff-backup) $PARAMETER $1 $FOLDERNAME 2>/dev/null)
    RDIFF2O=$($(which rdiff-backup) --force --remove-older-than $3 $1 2>/dev/null)

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

    if [ -n "$RDIFF1O" ]; then
        TARO="rdiff-backup:\t$RDIFF1O\n"
    fi

    if [ -n "$MKDIRO" ]; then
        MKDIRO="mount:\t$MKDIRO\n"
    fi

    SIZE="size total:\t$SIZET\nsize host:\t$SIZEH\nsize fabric:\t$SIZEF"

    if [ $DEBUG -gt 0 ]; then
        notifyadmin "$(hostname) $2 rdiff-backup" "-- FILES IN $FOLDERNAME --\n$NEWLISTING\n\n-- SIZE INFOS --\n$SIZE\n\n-- DEBUG INFOS --\n$MOUNT$RDIFF1O\n$RDIFF2O\n$MOUNTO$UMOUNTO$MKDIRO\n$CHOWNO"
    fi
}


function backup {
    mountbackup
    FILENAME="/$BACKUPDIR/oxibackup/$(hostname)/$2/$(date +%Y%m)/$(basename $1).$TIMESTAMP.tar.gz2"
    
    MKDIRO=$(mkdir -p $BACKUPDIR/oxibackup/$(hostname)/$2/$(date +%Y%m) 2>&1)
    TARO=$(/bin/tar -czf $FILENAME $1 2>/dev/null)
    
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
    
    if [ $DEBUG -gt 0 ]; then    
	notifyadmin "$(hostname) $2 backup" "-- FILES IN $BACKUPDIR/oxibackup/$(hostname)/$2/$(date +%Y%m) --\n$NEWLISTING\n\n-- SIZE INFOS --\n$SIZE\n\n-- DEBUG INFOS --\n$MOUNT$TARO$MOUNTO$UMOUNTO$MKDIRO" 
    fi
}

function rsyncbackup {
    while $(test -f /var/run/oxiscripts-rsyncbackup.pid); do sleep 10; done
    echo $$ > /var/run/oxiscripts-rsyncbackup.pid

    PARAMETER=""
    for DIR in ${EXCLUDED_DIR}; do
        PARAMETER="$PARAMETER--exclude $DIR "
    done

	if [ -z "$RSYNCPASSWORD" ]; then
		RSYNCO=$($(which rsync) -avh $3 ${PARAMETER} $1 $2)
	else
		echo "$RSYNCPASSWORD" > /etc/oxiscripts/rsyncpw-$$.tmp
		chmod 600 /etc/oxiscripts/rsyncpw-$$.tmp
		#RSYNCO=
		RSYNCO=$($(which rsync) -avh $3 --password-file=/etc/oxiscripts/rsyncpw-$$.tmp ${PARAMETER} $1 $2)
		rm /etc/oxiscripts/rsyncpw-$$.tmp
	fi

    if [ $DEBUG -gt 0 ]; then
        notifyadmin "$(hostname) $2 rsync-backup" "-- DEBUG INFOS --\n$RSYNCO"
    fi
    rm /var/run/oxiscripts-rsyncbackup.pid
}


function backupinfo {
    mountbackup
    
    SIZET="size total:\t$(du -sh $BACKUPDIR/oxibackup/)"
    SIZEH="size host:\t$(du -sh $BACKUPDIR/oxibackup/$(hostname)/)"

	SIZEF="size of oxibackup:\n"
    for FABRIC in $(ls $BACKUPDIR/oxibackup/$(hostname)/); do
	SIZEF="$SIZEF$(du -sh $BACKUPDIR/oxibackup/$(hostname)/$FABRIC)\n"
	for MONTH in $(ls $BACKUPDIR/oxibackup/$(hostname)/$FABRIC); do
	    SIZEF="$SIZEF$(du -sh $BACKUPDIR/oxibackup/$(hostname)/$FABRIC/$MONTH | awk '{print $1}')\t\t$MONTH\n"
	done
	SIZEF="$SIZEF\n\n"
    done

	if [ -d $BACKUPDIR/oxirdiffbackup/$(hostname)/ ]; then
		SIZEF="$SIZEFsize of oxirdiffbackup:\n"
	    for FABRIC in $(ls $BACKUPDIR/oxirdiffbackup/$(hostname)/); do
		SIZEF="$SIZEF$(du -sh $BACKUPDIR/oxirdiffbackup/$(hostname)/$FABRIC)\n"
		for FOLDER in $(ls $BACKUPDIR/oxirdiffbackup/$(hostname)/$FABRIC); do
		    SIZEF="$SIZEF$(du -sh $BACKUPDIR/oxirdiffbackup/$(hostname)/$FABRIC/$FOLDER | awk '{print $1}')\t\t$FOLDER\n"
		done
		SIZEF="$SIZEF\n"
	    done
	fi


    notifyadmin "$(hostname) backup info (uptime: $(uptime))" "-- $(hostname) backup usage --\n\n$SIZET\n$SIZEH\n\n-- fabrics --\n$SIZEF"

    umountbackup
}

function backupcleanup {
    mountbackup
    
    if [ -n $(which fdupes) ]; then
        SIZEBEFORE=$(du -sh $BACKUPDIR/oxibackup/$(hostname))
	COUNT=0
        for FILE in $(fdupes -r -f -q $BACKUPDIR/oxibackup/$(hostname)); do
		COUNT=$(($COUNT+1))
	    rm $FILE
        done
	SIZEAFTER=$(du -sh $BACKUPDIR/oxibackup/$(hostname))

        if [ $COUNT -gt 0 ]; then
	    notifyadmin "$(hostname) backup cleanup" "-- $(hostname) backup cleanup --\n\nfiles cleaned:\t$COUNT\nsize before:\t$SIZEBEFORE\nsize after:\t$SIZEAFTER"
        fi
    else
	nofityadmin "backup cleanup FAIL" "please install fdupes!"
    fi
    
    umountbackup
}

