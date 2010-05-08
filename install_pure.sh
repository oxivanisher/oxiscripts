#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=xxx

red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m' # No Color

echo -e "\n${BLUE}oXiScripts Setup! (oxi@mittelerde.ch)${NC}"
echo -e "${BLUE}--- Installing release: $INSTALLOXIRELEASE ---${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root${NC}" 2>&1
    exit 1
fi

echo -e "\nChecking for apps needed by install: \c"
if [ ! -n "$(which uudecode)" ]; then
	echo -e "\t${RED}Please install uudecode. (Mostly in package sharutils)${NC}"
	exit 1
fi
echo -e "OK"

echo -e "Creating $TARGETDIR: \c"
    mkdir -p $TARGETDIR/install
    mkdir -p $TARGETDIR/jobs
	mkdir -p $TARGETDIR/init.d
echo -e "Done"

echo -e "Extracting files: \c"
    match=$(grep --text --line-number '^PAYLOAD:$' $0 | cut -d ':' -f 1)
    payload_start=$((match+1))
    tail -n +$payload_start $0 | uudecode | tar -C $TARGETDIR/install -xz
echo -e "Done\n"

echo -e "Putting files in place: \c"
if [ -e $TARGETDIR/setup.sh ]; then
	echo -e "\n\tComparing the old and the new config:"
	mv $TARGETDIR/install/setup.sh $TARGETDIR/setup.sh.new

	echo -e "\t\tKeeping vars:" # ADMINMAIL,BACKUPDIR,DEBUG,SCRIPTSDIR,MOUNTO,UMOUNTO"

	function movevar {
		oldvar=$(egrep "$1" $TARGETDIR/setup.sh | sed 's/\&/\\\&/g')
		newvar=$(egrep "$1" $TARGETDIR/setup.sh.new | sed 's/\&/\\\&/g')
		if [  -n "$oldvar" ]; then
			sed -e "s|$newvar|$oldvar|g" $TARGETDIR/setup.sh.new > $TARGETDIR/setup.sh.tmp
			mv $TARGETDIR/setup.sh.tmp $TARGETDIR/setup.sh.new
			echo -e "\t\t\t${blue}$oldvar${NC}"
		fi
	}

	movevar '^export ADMINMAIL=.*$'
	movevar '^export BACKUPDIR=.*$'
	movevar '^export DEBUG=.*$'
	movevar '^export SCRIPTSDIR=.*$'
	movevar '^export OXIMIRROR=.*$'
	movevar '^\s*MOUNTO=.*$'
	movevar '^\s*UMOUNTO=.*$'

	mv $TARGETDIR/setup.sh.new $TARGETDIR/setup.sh
else
	mv $TARGETDIR/install/setup.sh $TARGETDIR/setup.sh
fi

mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh
mv $TARGETDIR/install/init.sh $TARGETDIR/init.sh
mv $TARGETDIR/install/virtualbox.sh $TARGETDIR/virtualbox.sh
mv $TARGETDIR/install/oxivbox $TARGETDIR/init.d/oxivbox

echo -e "\n\tIn case of an update, handle old jobfiles:"
for FILEPATH in $(ls $TARGETDIR/install/*.sh); do
FILE=$(basename $FILEPATH)
    if [ -e $TARGETDIR/jobs/$FILE ]; then
	if [ ! -n "$(diff -q $TARGETDIR/jobs/$FILE $TARGETDIR/install/$FILE)" ]; then
	    mv $TARGETDIR/install/$FILE $TARGETDIR/jobs/$FILE
	else
	    echo -e "${RED}->${NC}\t\t${red}$FILE is edited${NC}"
	    mv $TARGETDIR/install/$FILE $TARGETDIR/jobs/$FILE.new
	fi
    else
	mv $TARGETDIR/install/$FILE $TARGETDIR/jobs/$FILE
    fi
done

mv $TARGETDIR/install/* $TARGETDIR
rmdir $TARGETDIR/install


echo -e "\nSetting rights: \c"
	chmod 750 $TARGETDIR/init.d/*
    chmod 750 $TARGETDIR/jobs/*.sh
    chmod 640 $TARGETDIR/*.sh
	chmod 755 $TARGETDIR/init.sh
	chmod 755 $TARGETDIR/setup.sh
echo -e "Done"

echo -e "\nActivating jobs:"
	ln -s $TARGETDIR/init.d/oxivbox /etc/init.d/oxivbox
##monthly cron$
echo -e "\tActivating monthly backup statistic: \c"
    ln -sf $TARGETDIR/jobs/backup-info.sh /etc/cron.monthly/backup-info
echo -e "Done"

##weelky cron
echo -e "\tActivating weekly backup cleanup (saves a lot of space!): \c"
    ln -sf $TARGETDIR/jobs/backup-cleanup.sh /etc/cron.weekly/backup-cleanup
echo -e "Done"

echo -e "\tActivating weekly update check: \c"
    ln -sf $TARGETDIR/jobs/updatecheck.sh /etc/cron.weekly/updatecheck
echo -e "Done"

if [ -e /var/cache/apt/archives/ ]; then
	echo -e "\tActivating weekly cleanup of /var/cache/apt/archives/: \c"
	ln -sf $TARGETDIR/jobs/cleanup-apt.sh /etc/cron.weekly/cleanup-apt
	echo -e "Done"
fi

#daily cron
echo -e "\tActivating daily system, ~/scripts and ~/bin backup: \c"
    ln -sf $TARGETDIR/jobs/backup-system.sh /etc/cron.daily/backup-system
    ln -sf $TARGETDIR/jobs/backup-scripts.sh /etc/cron.daily/backup-scripts
echo -e "Done"


echo -e "\nSearching for some installed services:"

if [ $(which ejabberdctl) ]; then
    echo -e "\tFound ejabberd, installing daily backup and weekly avatar cleanup"
    ln -sf $TARGETDIR/jobs/cleanup-avatars.sh /etc/cron.weekly/cleanup-avatars
    ln -sf $TARGETDIR/jobs/backup-ejabberd.sh /etc/cron.daily/backup-ejabberd
fi

if [ $(which masqld) ]; then
    echo -e "\tFound mysql, installing daily backup"
    ln -sf $TARGETDIR/jobs/backup-mysql.sh /etc/cron.daily/backup-mysql
fi


#add init.sh to all .bashrc files
echo -e "\nFinding all .bashrc files to add init.sh (Currently doesn't support changing of the install dir!):"

function addtorc {
    if [ ! -n "$(grep oxiscripts/init.sh $1)" ];
    then
        echo -e "\tFound and editing file: $1"

        echo -e "\n#OXISCRIPTS HEADER (remove only as block!)" >> $1
        echo "if [ -f $TARGETDIR/init.sh ]; then" >> $1
	echo "       [ -z \"\$PS1\" ] && return" >> $1
	echo "       . $TARGETDIR/init.sh" >> $1
        echo "fi" >> $1
    else
        echo -e "\tFound but not editing file: $1"
    fi
}

for FILE in $(ls /root/.bashrc /home/*/.bashrc); do
    addtorc $FILE
done


echo -e "\nChecking for needed apps (These are only needed if you plan to use the module):"
	if [ ! -n "$(which rdiff-backup)" ]; then
		echo -e "\t${RED}Module backup-documents.sh requires rdiff-backup!${NC}"
	fi

	if [ ! -n "$(which fdupes)" ]; then
		echo -e "\t${RED}Module backup-clean.sh requires fdupes!${NC}"
	fi

	if [ ! -n "$(which rsync)" ]; then
		echo -e "\t${RED}Module backup-rsync.sh requires rsync!${NC}"
	fi

	if [ ! -n "$(which mailx)" ]; then
		echo -e "\t${RED}Any notification needs mailx!${NC}"
	fi
	if [ ! -n "$(which screen)" ]; then
		echo -e "\t${RED}The vbox init script needs screen!${NC}"
	fi


echo -e "\n${BLUE}Everything done.${NC}\n\n${RED}Please configure your jobs in $TARGETDIR/jobs!${NC}\n"
. /etc/oxiscripts/init.sh
exit 0

