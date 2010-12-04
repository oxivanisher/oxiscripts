#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=1291467456

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

echo -e "\n${cyan}Checking needed apps: \c"
if [ -z "$( which lsb_release 2>/dev/null )" ];
then
	if [ -n "$( which aptitude 2>/dev/null )" ];
	then
		aptitude install lsb-release -P || exit 1
	elif [ -n "$( which emerge 2>/dev/null )" ];
	then
		emerge lsb-release -av || exit 1
	else
		echo -e "\n${RED}Unable to install lsb_release${NC}"
		exit 1
	fi
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
			echo -e "${RED}Unsupported distribution: $LSBID${NC}; or lsb_release not found."
			exit 1
		;;
	esac

	echo -e "${cyan}Found supported distribution family: ${CYAN}$LSBID${NC}"
fi

if [ -z "$( which uudecode 2>/dev/null )" ]; then
	if [ "$LSBID" == "debian" ];
	then
		echo -e "${RED}Installing uudecode (aptitude install sharutils)${NC}"
		aptitude install sharutils -P || exit 1
	elif [ "$LSBID" == "gentoo" ];
	then
		echo -e "${RED}Installing uudecode (sharutils)${NC}"
		emerge sharutils -av || exit 1
	else
		echo -e "\n${RED}Unable to install uuencode${NC}"
		exit 1
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

echo -e "${cyan}Putting files in place${NC}\c"
function movevar {
	oldvar=$(egrep "$2" $TARGETDIR/$1 | sed 's/\&/\\\&/g')
	newvar=$(egrep "$2" $TARGETDIR/$1.new | sed 's/\&/\\\&/g')
	if [  -n "$oldvar" ]; then
		sed -e "s|$newvar|$oldvar|g" $TARGETDIR/$1.new > $TARGETDIR/$1.tmp
		mv $TARGETDIR/$1.tmp $TARGETDIR/$1.new
		echo -e "  ${cyan}$1:  ${CYAN}$oldvar${NC}"
	fi
}

if [ -e $TARGETDIR/setup.sh ]; then
	echo -e "\n${cyan}Checking old configuration"
	mv $TARGETDIR/install/setup.sh $TARGETDIR/setup.sh.new

	movevar "setup.sh" '^export ADMINMAIL=.*$'
	movevar "setup.sh" '^export BACKUPDIR=.*$'
	movevar "setup.sh" '^export DEBUG=.*$'
	movevar "setup.sh" '^export SCRIPTSDIR=.*$'
	movevar "setup.sh" '^export OXIMIRROR=.*$'
	movevar "setup.sh" '^export OXICOLOR=.*$'

	mv $TARGETDIR/setup.sh.new $TARGETDIR/setup.sh
else
	mv $TARGETDIR/install/setup.sh $TARGETDIR/setup.sh
fi

if [ -e $TARGETDIR/backup.sh ]; then
	mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh.new

	movevar "backup.sh" '^\s*MOUNTO=.*$'
	movevar "backup.sh" '^\s*UMOUNTO=.*$'

	mv $TARGETDIR/backup.sh.new $TARGETDIR/backup.sh
else
	mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh
fi

#mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh
mv $TARGETDIR/install/init.sh $TARGETDIR/init.sh
mv $TARGETDIR/install/virtualbox.sh $TARGETDIR/virtualbox.sh

mv $TARGETDIR/install/debian/* $TARGETDIR/debian
rmdir $TARGETDIR/install/debian

mv $TARGETDIR/install/gentoo/* $TARGETDIR/gentoo
rmdir $TARGETDIR/install/gentoo

mv $TARGETDIR/install/user/* $TARGETDIR/user
rmdir $TARGETDIR/install/user

echo -e "\n${cyan}Checking old jobfiles${NC}"
for FILEPATH in $(ls $TARGETDIR/install/jobs/*.sh); do
FILE=$(basename $FILEPATH)
	if [ -e $TARGETDIR/jobs/$FILE ]; then
		if [ ! -n "$(diff -q $TARGETDIR/jobs/$FILE $TARGETDIR/install/jobs/$FILE)" ]; then
			mv $TARGETDIR/install/jobs/$FILE $TARGETDIR/jobs/$FILE
		else
			echo -e "${RED}->${NC}    ${red}$FILE is edited${NC}"
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
	chmod -R 755 $TARGETDIR/debian/
	chmod -R 755 $TARGETDIR/gentoo/
	chmod -R 755 $TARGETDIR/user/

	chown -R root.root $TARGETDIR

echo -e "${CYAN}Done${NC}"

if [ "$LSBID" == "debian" ];
then
	if [ ! -e /etc/init.d/oxivbox ];
	then
		echo -e "  ${cyan}Activating debian vbox job${NC}"
		ln -s $TARGETDIR/debian/oxivbox.sh /etc/init.d/oxivbox
	fi

	echo -e "  ${cyan}Activating weekly update check: \c"
	ln -sf $TARGETDIR/debian/updatecheck.sh /etc/cron.weekly/updatecheck
	echo -e "${CYAN}Done${NC}"

	if [ -e /var/cache/apt/archives/ ]; then
		echo -e "  ${cyan}Activating weekly cleanup of /var/cache/apt/archives/: \c"
		ln -sf $TARGETDIR/debian/cleanup-apt.sh /etc/cron.weekly/cleanup-apt
		echo -e "${CYAN}Done${NC}"
	fi
fi
##monthly cron$
echo -e "  ${cyan}Activating monthly backup statistic: \c"
    ln -sf $TARGETDIR/jobs/backup-info.sh /etc/cron.monthly/backup-info
echo -e "${CYAN}Done${NC}"

##weelky cron
echo -e "  ${cyan}Activating weekly backup cleanup (saves a lot of space!): \c"
    ln -sf $TARGETDIR/jobs/backup-cleanup.sh /etc/cron.weekly/backup-cleanup
echo -e "${CYAN}Done${NC}"

#daily cron
echo -e "  ${cyan}Activating daily system, ~/scripts and ~/bin backup: \c"
    ln -sf $TARGETDIR/jobs/backup-system.sh /etc/cron.daily/backup-system
    ln -sf $TARGETDIR/jobs/backup-scripts.sh /etc/cron.daily/backup-scripts
echo -e "${CYAN}Done${NC}"


if [ $(which ejabberdctl 2>/dev/null ) ]; then
    echo -e "  ${CYAN}Found ejabberd, installing daily backup and weekly avatar cleanup${NC}"
    ln -sf $TARGETDIR/jobs/cleanup-avatars.sh /etc/cron.weekly/cleanup-avatars
    ln -sf $TARGETDIR/jobs/backup-ejabberd.sh /etc/cron.daily/backup-ejabberd
fi

if [ $(which masqld 2>/dev/null ) ]; then
    echo -e "  ${CYAN}Found mysql, installing daily backup${NC}"
    ln -sf $TARGETDIR/jobs/backup-mysql.sh /etc/cron.daily/backup-mysql
fi


# add init.sh to all .bashrc files
# (Currently doesn't support changing of the install dir!)
echo -e "\n${cyan}Finding all .bashrc files to add init.sh:${NC}"
function addtorc {
	if [ ! -n "$(grep oxiscripts/init.sh $1)" ];
	then
		echo -e "  ${cyan}Found and editing file: ${CYAN}$1${NC}"
		echo -e "\n#OXISCRIPTS HEADER (remove only as block!)" >> $1
		echo "if [ -f $TARGETDIR/init.sh ]; then" >> $1
		echo "       [ -z \"\$PS1\" ] && return" >> $1
		echo "       . $TARGETDIR/init.sh" >> $1
		echo "fi" >> $1
	else
		echo -e "  ${cyan}Found but not editing file: ${CYAN}$1${NC}"
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


install=""
doit="0"
echo -e "\n${cyan}Checking optional apps (These are only needed if you plan to use some of the modules/functions):\n  ${RED}\c"
BINS="rdiff-backup fdupes rsync mailx screen"
for BIN in $BINS
do
	if [ ! -n "$(which $BIN 2>/dev/null )" ]; then
		echo -e "$BIN \c"
		install="$install$BIN "
		doit="1"
	fi
done
echo -e "${NC}"

if [ "$doit" == "1" ];
then
	if [ "$LSBID" == "debian" ];
	then
		aptitude install $install -P
	elif [ "$LSBID" == "gentoo" ];
	then
		emerge $install -av
	fi
fi

echo -e "\n${BLUE}Everything done.${NC}\n\n${RED}Please configure your jobs in $TARGETDIR/jobs!${NC}\n"
. /etc/oxiscripts/init.sh
exit 0
PAYLOAD:
begin 644 -
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
"`0``
`
end
