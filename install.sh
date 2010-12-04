#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=1291487020

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
@6Z/$K<VX41X=DS]Z@^#Q\_AY_/QO/_\!`N<:\``8`0``
`
end
