#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=1290891413

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
	if [ ! -f $(dirname $FILE/.bashrc) ];
	then
		touch $(dirname $FILE/.bashrc)
	fi
	addtorc $(dirname $FILE/.bashrc)
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
PAYLOAD:
begin 644 -
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
#&`$`
`
end
