#!/bin/bash

# Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=xxx

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
	if [ -n "$( which apt-get 2>/dev/null )" ];
	then
		apt-get install lsb-release -qy || exit 1
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
		Debian|Raspbian|Ubuntu|Linuxmint)
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
		echo -e "${RED}Installing uudecode (apt-get install sharutils)${NC}"
		apt-get install sharutils -qy || exit 1
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
	# internal dirs
	mkdir -p $TARGETDIR/install
	mkdir -p $TARGETDIR/jobs
	mkdir -p $TARGETDIR/debian
	mkdir -p $TARGETDIR/gentoo
	mkdir -p $TARGETDIR/user

	# system dirs
	mkdir -p /var/log/oxiscripts/
echo -e "${CYAN}Done${NC}"

echo -e "${cyan}Extracting files: \c"
	match=$(grep --text --line-number '^PAYLOAD:$' $0 | cut -d ':' -f 1)
	payload_start=$((match+1))
	tail -n +$payload_start $0 | uudecode | tar -C $TARGETDIR/install -xz || exit 0
echo -e "${CYAN}Done${NC}"

echo -e "${cyan}Linking files \c"
	ln -sf $TARGETDIR/logrotate /etc/logrotate.d/oxiscripts
echo -e "${CYAN}Done${NC}"

echo -e "${cyan}Putting files in place${NC}\c"
movevar () {
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
	movevar "setup.sh" '^export BACKUPINFORDIFF=.*$'
	movevar "setup.sh" '^export DEBUG=.*$'
	movevar "setup.sh" '^export SCRIPTSDIR=.*$'
#	movevar "setup.sh" '^export OXIMIRROR=.*$'
	movevar "setup.sh" '^export OXICOLOR=.*$'

	mv $TARGETDIR/setup.sh.new $TARGETDIR/setup.sh
else
	mv $TARGETDIR/install/setup.sh $TARGETDIR/setup.sh
fi

# if [ -e $TARGETDIR/backup.sh ]; then
# 	mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh.new

# 	movevar "backup.sh" '^\s*MOUNTO=.*$'
# 	movevar "backup.sh" '^\s*UMOUNTO=.*$'

# 	mv $TARGETDIR/backup.sh.new $TARGETDIR/backup.sh
# else
# 	mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh
# fi

mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh

# mv $TARGETDIR/install/backup.sh $TARGETDIR/backup.sh
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

	chown -R root:root $TARGETDIR

echo -e "${CYAN}Done${NC}\n"

echo -e "${cyan}Configuring services${NC}"
if [ "$LSBID" == "debian" ];
then
	# some of those things are now no longer required and will be cleaned up

	# if [ ! -e /etc/init.d/oxivbox ];
	# then
	# 	echo -e "  ${cyan}Activating debian vbox job${NC}"
	# 	ln -s $TARGETDIR/debian/oxivbox.sh /etc/init.d/oxivbox
	# fi
	if [ -L /etc/init.d/oxivbox ]; then
		unlink /etc/init.d/oxivbox
	fi

	# echo -e "  ${cyan}Activating weekly update check: \c"
	# ln -sf $TARGETDIR/debian/updatecheck.sh /etc/cron.weekly/updatecheck
	# echo -e "${CYAN}Done${NC}"
	if [ -L /etc/cron.weekly/updatecheck ]; then
		unlink /etc/cron.weekly/updatecheck
	fi

	# if [ -e /var/cache/apt/archives/ ]; then
	# 	echo -e "  ${cyan}Activating weekly cleanup of /var/cache/apt/archives/: \c"
	# 	ln -sf $TARGETDIR/debian/cleanup-apt.sh /etc/cron.weekly/cleanup-apt
	# 	echo -e "${CYAN}Done${NC}"
	# fi
	if [ -L /etc/cron.weekly/cleanup-apt ]; then
		unlink /etc/cron.weekly/cleanup-apt
	fi

fi
## monthly cron
echo -e "  ${cyan}Activating monthly backup statistic: \c"
	ln -sf $TARGETDIR/jobs/backup-info.sh /etc/cron.monthly/backup-info
echo -e "${CYAN}Done${NC}"

## weelky cron
if [ -L /etc/cron.weekly/backup-cleanup ]; then
	echo -e "  ${cyan}Removing old weekly backup cleanup (this is now done daily): \c"
		unlink /etc/cron.weekly/backup-cleanup
	echo -e "${CYAN}Done${NC}"
fi

# daily cron
echo -e "  ${cyan}Activating daily system, ~/scripts and ~/bin backup: \c"
	ln -sf $TARGETDIR/jobs/backup-system.sh /etc/cron.daily/backup-system
	ln -sf $TARGETDIR/jobs/backup-scripts.sh /etc/cron.daily/backup-scripts
echo -e "${CYAN}Done${NC}"

echo -e "  ${cyan}Activating daily backup cleanup (saves a lot of space!): \c"
	ln -sf $TARGETDIR/jobs/backup-cleanup.sh /etc/cron.daily/backup-Z98-cleanup
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

echo -e "\n${cyan}Now activated services${NC}"
for FILE in $( ls -l /etc/cron.*/* | grep /etc/oxiscripts/jobs/ | awk '{print $9}' | sort )
do
	shedule="$( echo $FILE | sed 's/\/etc\/cron\.//g' | sed 's/\// /g' | awk '{print $1}' )"
	file="$( echo $FILE | sed 's/\/etc\/cron\.//g' | sed 's/\// /g' | awk '{print $2}' )"
	printf "  ${CYAN}%-30s ${cyan}%s${NC}\n" $file $shedule
done


# add init.sh to all .bashrc files
# (Currently doesn't support changing of the install dir!)
addtorc () {
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

# additionally, let it load this way too
if [ -d "/etc/profile.d/" ];
then
	if [ ! -L "/etc/profile.d/oxiscripts.sh" ];
	then
		echo -e "\n${cyan}Linking /etc/profile.d/oxiscripts.sh${NC}"
		ln -s $TARGETDIR/init.sh /etc/profile.d/oxiscripts.sh
	else
		echo -e "\n${cyan}/etc/profile.d/oxiscripts.sh already exists${NC}"
	fi
fi

echo -e "\n${cyan}Checking user profiles to add init.sh${NC}"
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
	chown $username:$username $tname
	chmod 644 $tname
done

install=""
doit="0"
echo -e "\n${cyan}Checking and installing optional apps\n  \c"
BINS="rdiff-backup fdupes rsync bsd-mailx screen"
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
		apt-get install -qy $install
	elif [ "$LSBID" == "gentoo" ];
	then
		emerge $install -av
	fi
fi

echo -e "\n${BLUE}Everything done.${NC}\n"
. /etc/oxiscripts/init.sh
exit 0
