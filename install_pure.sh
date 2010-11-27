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
echo -e "${blue}--- Installing release: $INSTALLOXIRELEASE ---${NC}"

if [[ $EUID -ne 0 ]];
then
	echo -e "${RED}This script must be run as root${NC}" 2>&1
	exit 1
fi

echo -e "\n${cyan}Checking for apps needed by install: \c"
if [ ! -n "$( which lsb_release 2>/dev/null )" ];
then
	if [ ! -n "$( which aptitude 2>/dev/null )" ];
	then
		aptitude install lsb-release -P
	elif [ ! -n "$( which emerge 2>/dev/null )" ];
	then
		emerge lsb-release -av
	fi
	echo -e "\t${RED}Please install lsb_release${NC}"
	exit 1
else
	echo -e "${CYAN}Done${NC}"

	case "$(lsb_release -is)" in
		Debian|Ubuntu)
			LSBID="debian"
		;;
		Gentoo)
			LSBID="gentoo"
		;;
#		RedHatEnterpriseServer|CentOS)
#			LSBID="redhat"
#		;;
		*)
			echo -e "${RED}Unsupported distribution: $LSBID${NC}"
			exit 1
		;;
	esac

	echo -e "${cyan}Found supported distribution family: ${CYAN}$LSBID${NC}"
fi

if [ ! -n "$( which uudecode 2>/dev/null )" ]; then
	if [ "$LSBID" == "debian" ];
	then
		echo -e "\t${RED}Installing uudecode (aptitude install sharutils)${NC}"
		aptitude install sharutils -P || exit 0
	elif [ "$LSBID" == "gentoo" ];
	then
		echo -e "\t${RED}Installing uudecode (sharutils)${NC}"
		emerge sharutils -av || exit 1
	fi
fi

echo -e "${cyan}Creating ${CYAN}$TARGETDIR: ${NC}\c"
	mkdir -p $TARGETDIR/install
	mkdir -p $TARGETDIR/jobs
	mkdir -p $TARGETDIR/debian
	mkdir -p $TARGETDIR/gentoo
	mkdir -p $TARGETDIR/user
echo -e "${cyan}Done${NC}"

echo -e "${cyan}Extracting files: \c"
	match=$(grep --text --line-number '^PAYLOAD:$' $0 | cut -d ':' -f 1)
	payload_start=$((match+1))
	tail -n +$payload_start $0 | uudecode | tar -C $TARGETDIR/install -xz || exit 0
echo -e "${CYAN}Done${NC}"

echo -e "${cyan}Putting files in place: \c${NC}"
if [ -e $TARGETDIR/setup.sh ]; then
	echo -e "\n  Comparing the old and the new config:"
	mv $TARGETDIR/install/setup.sh $TARGETDIR/setup.sh.new

	echo -e "    ${cyan}Keeping vars:${NC}" # ADMINMAIL,BACKUPDIR,DEBUG,SCRIPTSDIR,MOUNTO,UMOUNTO"

	function movevar {
		oldvar=$(egrep "$1" $TARGETDIR/setup.sh | sed 's/\&/\\\&/g')
		newvar=$(egrep "$1" $TARGETDIR/setup.sh.new | sed 's/\&/\\\&/g')
		if [  -n "$oldvar" ]; then
			sed -e "s|$newvar|$oldvar|g" $TARGETDIR/setup.sh.new > $TARGETDIR/setup.sh.tmp
			mv $TARGETDIR/setup.sh.tmp $TARGETDIR/setup.sh.new
			echo -e "      ${blue}$oldvar${NC}"
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

mv $TARGETDIR/install/debian/* $TARGETDIR/debian
rmdir $TARGETDIR/install/debian

mv $TARGETDIR/install/gentoo/* $TARGETDIR/gentoo
rmdir $TARGETDIR/install/gentoo

mv $TARGETDIR/install/user/* $TARGETDIR/user
rmdir $TARGETDIR/install/user

echo -e "\n${cyan}In case of an update, handle old jobfiles${NC}"
for FILEPATH in $(ls $TARGETDIR/install/jobs/*.sh); do
FILE=$(basename $FILEPATH)
	if [ -e $TARGETDIR/jobs/$FILE ]; then
		if [ ! -n "$(diff -q $TARGETDIR/jobs/$FILE $TARGETDIR/install/jobs/$FILE)" ]; then
			mv $TARGETDIR/install/jobs/$FILE $TARGETDIR/jobs/$FILE
		else
			echo -e "${RED}->${NC}\t\t${red}$FILE is edited${NC}"
			mv $TARGETDIR/install/jobs/$FILE $TARGETDIR/jobs/$FILE.new
		fi
	else
		mv $TARGETDIR/install/jobs/$FILE $TARGETDIR/jobs/$FILE
	fi
done
rmdir $TARGETDIR/install/jobs/

find $TARGETDIR/install/ -maxdepth 1 -type f -exec mv {} $TARGETDIR \;
rmdir $TARGETDIR/install

echo -e "\n${cyan}Setting rights: \c"

	chmod 640 $TARGETDIR/*.sh
	chmod 755 $TARGETDIR/init.sh
	chmod 644 $TARGETDIR/functions.sh
	chmod 644 $TARGETDIR/virtualbox.sh
	chmod 644 $TARGETDIR/setup.sh
	chmod -R 750 $TARGETDIR/jobs/
	chmod -R 750 $TARGETDIR/debian/
	chmod -R 750 $TARGETDIR/gentoo/
	chmod -R 755 $TARGETDIR/user/

	chown -R root.root $TARGETDIR

echo -e "${CYAN}Done${NC}"

if [ "$LSBID" == "debian" ];
then
	if [ ! -e /etc/init.d/oxivbox ];
	then
		echo -e "\t${cyan}Activating debian vbox job${NC}"
		ln -s $TARGETDIR/debian/oxivbox.sh /etc/init.d/oxivbox
	fi

	echo -e "\t${cyan}Activating weekly update check: \c"
	ln -sf $TARGETDIR/debian/updatecheck.sh /etc/cron.weekly/updatecheck
	echo -e "${CYAN}Done${NC}"

	if [ -e /var/cache/apt/archives/ ]; then
		echo -e "\t${cyan}Activating weekly cleanup of /var/cache/apt/archives/: \c"
		ln -sf $TARGETDIR/debian/cleanup-apt.sh /etc/cron.weekly/cleanup-apt
		echo -e "${CYAN}Done${NC}"
	fi
fi
##monthly cron$
echo -e "\t${cyan}Activating monthly backup statistic: \c"
    ln -sf $TARGETDIR/jobs/backup-info.sh /etc/cron.monthly/backup-info
echo -e "${CYAN}Done${NC}"

##weelky cron
echo -e "\t${cyan}Activating weekly backup cleanup (saves a lot of space!): \c"
    ln -sf $TARGETDIR/jobs/backup-cleanup.sh /etc/cron.weekly/backup-cleanup
echo -e "${CYAN}Done${NC}"

#daily cron
echo -e "\t${cyan}Activating daily system, ~/scripts and ~/bin backup: \c"
    ln -sf $TARGETDIR/jobs/backup-system.sh /etc/cron.daily/backup-system
    ln -sf $TARGETDIR/jobs/backup-scripts.sh /etc/cron.daily/backup-scripts
echo -e "${CYAN}Done${NC}"


if [ $(which ejabberdctl 2>/dev/null ) ]; then
    echo -e "\t${CYAN}Found ejabberd, installing daily backup and weekly avatar cleanup${NC}"
    ln -sf $TARGETDIR/jobs/cleanup-avatars.sh /etc/cron.weekly/cleanup-avatars
    ln -sf $TARGETDIR/jobs/backup-ejabberd.sh /etc/cron.daily/backup-ejabberd
fi

if [ $(which masqld 2>/dev/null ) ]; then
    echo -e "\t${CYAN}Found mysql, installing daily backup${NC}"
    ln -sf $TARGETDIR/jobs/backup-mysql.sh /etc/cron.daily/backup-mysql
fi


# add init.sh to all .bashrc files
# (Currently doesn't support changing of the install dir!)
echo -e "\n${cyan}Finding all .bashrc files to add init.sh:${NC}"
function addtorc {
	if [ ! -n "$(grep oxiscripts/init.sh $1)" ];
	then
		echo -e "\t${cyan}Found and editing file: ${CYAN}$1${NC}"
		echo -e "\n#OXISCRIPTS HEADER (remove only as block!)" >> $1
		echo "if [ -f $TARGETDIR/init.sh ]; then" >> $1
		echo "       [ -z \"\$PS1\" ] && return" >> $1
		echo "       . $TARGETDIR/init.sh" >> $1
		echo "fi" >> $1
	else
		echo -e "\t${cyan}Found but not editing file: ${CYAN}$1${NC}"
	fi
}

if [ ! -f /root/.bash_profile ];
then
	echo -e "#!/bin/bash\n[[ -f ~/.bashrc ]] && . ~/.bashrc" >> /root/.bash_profile
fi
touch /root/.bashrc
addtorc /root/.bashrc
for FILE in $(ls /home/*/.bash_history); do
	tname="$( dirname $FILE )/.bashrc"
	username=$( dirname $FILE | sed 's/home//g' | sed 's/\.bash_history//g' | sed 's/\///g' )
	touch $tname
	addtorc $tname
	chown $username.$username $tname
	chmod 644 $tname
done


echo -e "\n${cyan}Checking for optional apps (These are only needed if you plan to use some of the modules/functions):\n\t${RED}\c"
BINS="rdiff-backup fdupes rsync mailx screen"
for BIN in $BINS
do
	if [ ! -n "$(which $BIN 2>/dev/null )" ]; then
		echo -e "$BIN \c"
	fi
done
echo -e "${NC}"

echo -e "\n${BLUE}Everything done.${NC}\n\n${RED}Please configure your jobs in $TARGETDIR/jobs!${NC}\n"
. /etc/oxiscripts/init.sh
exit 0
