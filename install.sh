#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=1291487368

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
!````
`
end
