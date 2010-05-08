#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=1268840460

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

PAYLOAD:
begin 644 -
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
4LWI6S^I9/?_#SW\`HSKP=`#(````
`
end
