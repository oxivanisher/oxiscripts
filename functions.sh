#!/bin/bash
. /etc/oxiscripts/setup.sh

# Load system functions
export OXISCRIPTSFUNCTIONS="ox-help"
function ox-help {
	if [ "$1" == "--help" ]; then
		echo "show this help"
		return 0
	fi

	echo -e ""
	#${#str_var}
	max_len=0
	FUNCTS=$( echo $OXISCRIPTSFUNCTIONS | sed 's/:/\n/g' | sort )
	for MODULE in ${FUNCTS}
	do
		if [ ${#MODULE} -gt $max_len ];
		then
			max_len=${#MODULE}
		fi
	done
	max_len=$(( $max_len + 2 ))

	echo -e "${BLUE}Available oXiScript functions ${blue}(release $OXIRELEASE)${NC}"
	save=""
	for MODULE in ${FUNCTS}
	do
		if [ "$MODULE" != "" ];
		then
			if [ "${MODULE:0:6}" != "$save" ];
			then
				save="${MODULE:0:6}"
				echo -e ""
			fi
			printf "${CYAN}%-${max_len}s ${cyan}%s \n${NC}"  "$MODULE" "$( $MODULE --help )"
		fi
	done
	echo -e ""
}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-base-show"
function ox-base-show {
	if [ "$1" == "--help" ]; then
		echo "show configuration variables"
		return 0
	fi

	. /etc/oxiscripts/setup.sh
	echo -e "ADMINMAIL\t$ADMINMAIL"
	echo -e "BACKUPDIR\t$BACKUPDIR"
	echo -e "DEBUG\t\t$DEBUG"
	echo -e "SCRIPTSDIR\t$SCRIPTSDIR"
	echo -e "OXIMIRROR\t$OXIMIRROR"
	echo -e "OXICOLOR\t$OXICOLOR"
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

function ox-zint-log {
	mystring=${@}
	if [ -n "$mystring" ];
	then
		logger -t "$(whoami)@OX" "$mystring"
	fi
}

function ox-zint-notify {
	mystring=${@}
	length=$(( ${#mystring} + 3 ))
	line=""
	for (( i=0; i<=$length; i++ ))
	do
		line="${line}-"
	done
	echo -e "\n${BLUE}$line${NC}"
	echo -e "${BLUE}| ${cyan}$mystring ${BLUE}|${NC}"
	echo -e "${BLUE}$line${NC}\n"
}

function ox-zint-alert {
	ox-zint-log ${@}
	mystring=${@}
	length=$(( ${#mystring} + 3 ))
	line=""
	for (( i=0; i<=$length; i++ ))
	do
		line="${line}#"
	done
	echo -e "\n${BLUE}$line${NC}"
	echo -e "${BLUE}# ${RED}$mystring ${BLUE}#${NC}"
	echo -e "${BLUE}$line${NC}\n"
}

function ox-zint-run {
	runts=$(date +%s)
	ox-zint-alert "Running: ${@}"
	${@}
	ox-zint-notify "Command took $(( $(date +%s) - $runts )) seconds."
}

# Load root functions
if [[ $EUID -eq 0 ]];
then
	#oxiscripts update function
	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-base-update"
	function ox-base-update {
		if [ "$1" == "--help" ]; then
			echo "update from $OXIMIRROR"
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
		if [ "$( $(which md5sum) /tmp/$(basename $OXIMIRROR) | awk '{print $1}')" = "$(cat /tmp/$(basename $OXIMIRROR).md5 | awk '{print $1}')" ]; then
			echo -e "${CYAN}OK${NC}"

			chmod +x /tmp/$(basename $OXIMIRROR)
			export $(egrep '^INSTALLOXIRELEASE=.*$' /tmp/$(basename $OXIMIRROR))
			echo -e "${cyan}Actual Release:\t${CYAN}$OXIRELEASE${NC}\n${cyan}New Release:\t${CYAN}$INSTALLOXIRELEASE${NC}"
	
			if [ "$OXIRELEASE" -lt "$INSTALLOXIRELEASE" ]; then
				echo -e "\n${RED}--- Initiating oXiScripts update ---${NC}"
				/tmp/install.sh
				. /etc/oxiscripts/init.sh
			elif [ "$OXIRELEASE" -eq "$INSTALLOXIRELEASE" ]; then
				echo -e "${BLUE}You have already the newest version. :)${NC}"
				echo -e "${cyan}If you like to reinstall oxiscripts, please run ${CYAN}/tmp/$(basename $OXIMIRROR)${NC}"
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
			echo "set configuration OPTION"
			return 0
		fi

		if [[ ${EUID} != 0 ]] ; then
			echo -e "${RED}This function must be run as root. Sorry!${NC}"
		else
			case "$1" in
				debug)
					echo -e "${cyan}Toggling ${CYAN}DEBUG to: \c"
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

				color)
					echo -e "${cyan}Toggling ${CYAN}COLOR to: \c"
					if [ $OXICOLOR -eq 0 ]; then
						echo -e "${RED}Enabled${NC}"
						sed 's/OXICOLOR=0/OXICOLOR=1/g' /etc/oxiscripts/setup.sh > /tmp/setup.sh
						mv /tmp/setup.sh /etc/oxiscripts/setup.sh
					else
						echo -e "${BLUE}Disabled${NC}"
						sed 's/OXICOLOR=1/OXICOLOR=0/g' /etc/oxiscripts/setup.sh > /tmp/setup.sh
						mv /tmp/setup.sh /etc/oxiscripts/setup.sh
					fi
				;;

				mirror)
					if [ -n "$2" ]; then
						echo -e "${cyan}Setting MIRROR to: ${RED}$2${NC}"
						sed "s|OXIMIRROR=$(echo $OXIMIRROR)|OXIMIRROR=$(echo $2)|g" /etc/oxiscripts/setup.sh > /tmp/setup.sh
						mv /tmp/setup.sh /etc/oxiscripts/setup.sh
					else
						echo -e "${RED}Please add a URL${NC}"
					fi
				;;

				mail)
					if [ -n "$2" ]; then
						echo -e "${cyan}Setting MAIL to: ${RED}$2${NC}"
						sed "s|ADMINMAIL=$(echo $ADMINMAIL)|ADMINMAIL=$(echo $2)|g" /etc/oxiscripts/setup.sh > /tmp/setup.sh
						mv /tmp/setup.sh /etc/oxiscripts/setup.sh
					else
						echo -e "${RED}Please add a Email Adress${NC}"
					fi
				;;

				*)
					echo -e "${RED}No corresponding keyword found: $1${NC}"
					echo -e "\t${CYAN}Possible are: debug, color, mirror and mail${NC}"
				;;

			esac
			echo -e "${red}Only new spawned enviroments have the variable set. Please relog.${NC}"
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

		if [ -n "$( which apt-get 2>/dev/null )" ]; then
			echo -e "You are on a Debian system. Automatically installing needed packages."
			apt-get -y install build-essential linux-headers-$(uname -r)
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
