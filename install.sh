#!/bin/bash

#Please do not add a / at the end of the following line!
TARGETDIR=/etc/oxiscripts


INSTALLOXIRELEASE=1290893434

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
PAYLOAD:
begin 644 -
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
K:Z\LE+M]\K\^(&A#&]K0AC:TH0UM:$,;VM"&-K2A#?_[\#<#P69U`!@!````
`
end
