#!/bin/bash
. /etc/oxiscripts/setup.sh

# Load system functions
export OXISCRIPTSFUNCTIONS="ox-help"
function ox-help {
	if [ "$1" == "--help" ]; then
		echo "show this help"
		return 0
	fi

	echo -e "${BLUE}Available oXiScript functions:${NC}"
	FUNCTS=$( echo $OXISCRIPTSFUNCTIONS | sed 's/:/ /g' )
	for MODULE in ${FUNCTS}
	do
		if [ "$MODULE" != "" ];
		then
			echo -e "${red}$MODULE\t\t\t${cyan}$( $MODULE --help )${NC}"
		fi
	done
}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-base-get"
function ox-base-get {
	if [ "$1" == "--help" ]; then
		echo "get configuration variables"
		return 0
	fi

	. /etc/oxiscripts/setup.sh
	echo -e "ADMINMAIL\t$ADMINMAIL"
	echo -e "BACKUPDIR\t$BACKUPDIR"
	echo -e "DEBUG\t\t$DEBUG"
	echo -e "SCRIPTSDIR\t$SCRIPTSDIR"
	echo -e "OXIMIRROR\t$OXIMIRROR"
}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-base-notifyadmin"
function ox-base-notifyadmin {
	if [ "$1" == "--help" ]; then
		echo "send email notification to admin ($ADMINMAIL)"
		return 0
	fi

	if [ "$0" = "-bash" ]; then
		SOURCE="Console"
	else
		SOURCE=$(basename "$0")
	fi
	echo -e "$2" | $MAILCOMMAND -s "$1 ($SOURCE)" $ADMINMAIL
}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-base-showrelease"
function ox-base-showrelease {
	if [ "$1" == "--help" ]; then
		echo "show release version ($OXIRELEASE)"
		return 0
	fi
	echo -e "oXiScripts Release: $OXIRELEASE ($(echo $OXIRELEASE|awk '{print strftime("%c", $1)}'))"
}

# Load root functions
if [[ $EUID -eq 0 ]];
then
	#oxiscripts update function
	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-base-update"
	function ox-base-update {
		if [ "$1" == "--help" ]; then
			echo "updates oxiscripts from mirror"
			return 0
		fi

		echo -e "\n${BLUE}--- oXiScripts autoupdate ---${NC}"
		if [[ ${EUID} != 0 ]] ; then
			echo -e "This function must be run as root. Sorry!"
			exit 1
		fi

		echo -e "${cyan}Downloading:\t\c${RED}"
		wget -qq -r $OXIMIRROR -O /tmp/$(basename $OXIMIRROR)
		wget -qq -r $OXIMIRROR.md5 -O /tmp/$(basename $OXIMIRROR.md5)
		echo -e "${CYAN}Done"

		echo -e "${cyan}MD5 Checksum:\t\c"
		if [ "$(md5sum /tmp/$(basename $OXIMIRROR) | awk '{print $1}')" = "$(cat /tmp/$(basename $OXIMIRROR).md5 | awk '{print $1}')" ]; then
			echo -e "${CYAN}OK${NC}"

			chmod +x /tmp/$(basename $OXIMIRROR)
			export $(egrep '^INSTALLOXIRELEASE=.*$' /tmp/$(basename $OXIMIRROR))
			echo -e "${cyan}Actual Release:\t${CYAN}$OXIRELEASE${NC}\n${cyan}New Release:\t${CYAN}$INSTALLOXIRELEASE${NC}"
	
			if [ "$OXIRELEASE" -lt "$INSTALLOXIRELEASE" ]; then
				echo -e "${BLUE}--- Updating oXiScripts ---${NC}"
				/tmp/install.sh
				. /etc/oxiscripts/init.sh
			elif [ "$OXIRELEASE" -eq "$INSTALLOXIRELEASE" ]; then
				echo -e "${BLUE}You have already the newest version. :)${NC}"
				echo -e "If you like to reinstall oxiscripts, please run /tmp/$(basename $OXIMIRROR)"
			elif [ "$OXIRELEASE" -gt "$INSTALLOXIRELEASE" ]; then
				echo -e "\n${RED}Your mirror is old or you have messed around with OXIRELEASE in /etc/oxiscripts/setup.sh${NC}\n"
			else
				echo -e "\n${RED}Some strange error occured:${NC} actual release [$OXIRELEASE], new release [$INSTALLOXIRELEASE]\n"
			fi
		else
			echo -e "${RED}Not OK!${NC}"
		fi
	}

	#oxiscripts set function
	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-base-set"
	function ox-base-set {
		. /etc/oxiscripts/setup.sh
		if [ "$1" == "--help" ]; then
			echo "set configuration variable"
			return 0
		fi

		if [[ ${EUID} != 0 ]] ; then
			echo -e "This function must be run as root. Sorry!"
		else
			case "$1" in
				debug)
					echo -e "Toggling DEBUG to: \c"
					if [ $DEBUG -eq 0 ]; then
						echo -e "${RED}Enabled${NC}"
						sed 's/DEBUG=0/DEBUG=1/g' /etc/oxiscripts/setup.sh > /tmp/setup.sh
						mv /tmp/setup.sh /etc/oxiscripts/setup.sh
					else
						echo -e "${BLUE}Disabled${NC}"
						sed 's/DEBUG=1/DEBUG=0/g' /etc/oxiscripts/setup.sh > /tmp/setup.sh
						mv /tmp/setup.sh /etc/oxiscripts/setup.sh
					fi
				;;

				mirror)
					if [ -n "$2" ]; then
						echo -e "Setting MIRROR to: ${RED}$2${NC}"
						sed "s|OXIMIRROR=$(echo $OXIMIRROR)|OXIMIRROR=$(echo $2)|g" /etc/oxiscripts/setup.sh > /tmp/setup.sh
						mv /tmp/setup.sh /etc/oxiscripts/setup.sh
					else
						echo -e "Please add a URL"
					fi
				;;

				mail)
					if [ -n "$2" ]; then
						echo -e "Setting MAIL to: ${RED}$2${NC}"
						sed "s|ADMINMAIL=$(echo $ADMINMAIL)|ADMINMAIL=$(echo $2)|g" /etc/oxiscripts/setup.sh > /tmp/setup.sh
						mv /tmp/setup.sh /etc/oxiscripts/setup.sh
					else
						echo -e "Please add a Email Adress"
					fi
				;;

				*)
					echo -e "No corresponding keyword found: $1"
					echo -e "\tPossible are: debug, mirror and mail"
				;;

			esac
		fi
	}


	## VirtualBox stuff
	#oxivbox-addonsupdate
	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-vbox-client-addonsupdate"
	function ox-vbox-client-addonsupdate {
		if [ "$1" == "--help" ]; then
			echo "updates vbox client addons"
			return 0
		fi

		if [ "$(uname -m)" = "i686" ];
		then
			MTYPE="x86"
		elif [ "$(uname -m)" = "x86_64" ];
		then
			MTYPE="amd64"
		fi
		echo -e "Machine type: $MTYPE"

		if [ -n "$( which aptitude 2>/dev/null )" ]; then
			echo -e "You are on a Debian system. Automatically installing needed packages."
			aptitude -y install build-essential linux-headers-$(uname -r)
		else
			echo -e "You are NOT on a Debian system. Please check for all needed dependencies!"
		fi

		mount /cdrom
		if [ -f /cdrom/VBoxLinuxAdditions-$MTYPE.run ];
		then
			cp /cdrom/VBoxLinuxAdditions-$MTYPE.run /tmp
			/tmp/VBoxLinuxAdditions-$MTYPE.run
		else
			echo -e "Unable to find the files. Please set the CDROM to the vbox guest additions cd iso."
		fi

		umount /cdrom

		echo -e "\nPlease press Ctrl+C within the next 30 seconds to NOT reboot your system!"
		sleep 30 && reboot && exit
	}
fi

# Load user functions
if [ -f "/etc/oxiscripts/user/init.sh" ];
then
	. "/etc/oxiscripts/user/init.sh"
fi

if [ ! -z "$( which VBoxManage 2>/dev/null )" ];
then
	. /etc/oxiscripts/virtualbox.sh
fi

# Load variables
if [ -f $SCRIPTDIR/init.sh ];
then
    . $SCRIPTDIR/init.sh
fi