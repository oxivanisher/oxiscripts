#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=1291471016

red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m' # No Color

echo -e "\n${BLUE}oxiscripts install (oxi@mittelerde.ch)${NC}"
echo -e "${cyan}--- Installing release: ${CYAN}$INSTALLOXIRELEASE${cyan} ---${NC}"

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

echo -e "${cyan}Creating ${CYAN}$TARGETDIR${cyan}: ${NC}\c"
	mkdir -p $TARGETDIR/install
	mkdir -p $TARGETDIR/jobs
	mkdir -p $TARGETDIR/debian
	mkdir -p $TARGETDIR/gentoo
	mkdir -p $TARGETDIR/user
echo -e "${CYAN}Done${NC}"

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
		echo -e "  ${cyan}$1:  ${CYAN}$( echo $oldvar | sed 's/export //g' )${NC}"
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

echo -e "\n${cyan}Setting permissions: \c"

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

echo -e "${CYAN}Done${NC}\n"

echo -e "${cyan}Enabling services${NC}"
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

echo -e "\n${cyan}Activated services${NC}"
for FILE in $( ls -l /etc/cron.*/* | grep /etc/oxiscripts/jobs/ | awk '{print $9}' | sort )
do
	shedule="$( echo $FILE | sed 's/\/etc\/cron\.//g' | sed 's/\// /g' | awk '{print $1}' )"
	file="$( echo $FILE | sed 's/\/etc\/cron\.//g' | sed 's/\// /g' | awk '{print $2}' )"
	printf "  ${CYAN}%-30s ${cyan}%s${NC}\n" $file $shedule
done


# add init.sh to all .bashrc files
# (Currently doesn't support changing of the install dir!)
echo -e "\n${cyan}Checking user profiles to add init.sh${NC}"
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
echo -e "\n${cyan}Checking optional apps\n  \c"
BINS="rdiff-backup fdupes rsync mailx screen"
for BIN in $BINS
do
	if [ ! -n "$(which $BIN 2>/dev/null )" ]; then
		echo -e "${RED}$BIN${NC} \c"
		install="$install$BIN "
		doit="1"
	else
		echo -e "${cyan}$BIN${NC} \c"
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

echo -e "\n${BLUE}Everything done.${NC}\n"
. /etc/oxiscripts/init.sh
exit 0
PAYLOAD:
begin 644 -
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
(4,SWLP`8`0``
`
end
