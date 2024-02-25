#!/bin/bash
#
# This file is sourced by all *interactive* bash shells on startup,
# including some apparently interactive shells such as scp and rcp
# that can't tolerate any output.  So make sure this doesn't display
# anything or bad things will happen !


# SETUP!
# A lot of this file is copied from the gentoo bashrc file from
# https://gitweb.gentoo.org/repo/gentoo.git/tree/app-shells/bash/files/bashrc

# Test for an interactive shell.  There is no need to set anything
# past this point for scp and rcp, and it's important to refrain from
# outputting anything in those cases.
if [[ $- != *i* ]] ; then
	# Shell is non-interactive. Be done now!
	return
fi

# Thanks lightdm ...
# https://unix.stackexchange.com/questions/552459/why-does-lightdm-source-my-profile-even-though-my-login-shell-is-zsh
# https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/1468832
if [[ "$(ps -o args= $PPID)" == *"lightdm"* ]] ; then
	# Help, its a lightdm login session. Be gone!
	return
fi

. /etc/oxiscripts/setup.sh

# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
shopt -s checkwinsize

# Disable completion when the input buffer is empty.  i.e. Hitting tab
# and waiting a long time for bash to expand all of $PATH.
shopt -s no_empty_cmd_completion

# Enable history appending instead of overwriting when exiting.  #139609
shopt -s histappend

# Save each command to the history file as it's executed.  #517342
# This does mean sessions get interleaved when reading later on, but this
# way the history is always up to date.  History is not synced across live
# sessions though; that is what `history -n` does.
# Disabled by default due to concerns related to system recovery when $HOME
# is under duress, or lives somewhere flaky (like NFS).  Constantly syncing
# the history will halt the shell prompt until it's finished.
#PROMPT_COMMAND='history -a'

# Change the window title of X terminals
case ${TERM} in
	[aEkx]term*|rxvt*|gnome*|konsole*|interix)
		PS1='\[\033]0;\u@\h:\w\007\]'
		;;
	screen*)
		PS1='\[\033k\u@\h:\w\033\\\]'
		;;
	*)
		unset PS1
		;;
esac

# Set colorful PS1 only on colorful terminals.
# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.
# We run dircolors directly due to its changes in file syntax and
# terminal name patching.
use_color=false
if type -P dircolors >/dev/null ; then
	# Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
	LS_COLORS=
	if [[ -f ~/.dir_colors ]] ; then
		eval "$(dircolors -b ~/.dir_colors)"
	elif [[ -f /etc/DIR_COLORS ]] ; then
		eval "$(dircolors -b /etc/DIR_COLORS)"
	else
		eval "$(dircolors -b)"
	fi
	# Note: We always evaluate the LS_COLORS setting even when it's the
	# default.  If it isn't set, then `ls` will only colorize by default
	# based on file attributes and ignore extensions (even the compiled
	# in defaults of dircolors). #583814
	if [[ -n ${LS_COLORS:+set} ]] ; then
		use_color=true
	else
		# Delete it if it's empty as it's useless in that case.
		unset LS_COLORS
	fi
else
	# Some systems (e.g. BSD & embedded) don't typically come with
	# dircolors so we need to hardcode some terminals in here.
	case ${TERM} in
	[aEkx]term*|rxvt*|gnome*|konsole*|screen|cons25|*color) use_color=true;;
	esac
fi

if ${use_color} ; then
	if [[ ${EUID} == 0 ]] ; then
		PS1+='\[\033[01;31m\]\h\[\033[01;34m\] \w \$\[\033[00m\] '
	else
		PS1+='\[\033[01;32m\]\u@\h\[\033[01;34m\] \w \$\[\033[00m\] '
	fi

	#BSD#@export CLICOLOR=1
	#GNU#@alias ls='ls --color=auto'
	alias grep='grep --colour=auto'
	alias egrep='egrep --colour=auto'
	alias fgrep='fgrep --colour=auto'
else
	if [[ ${EUID} == 0 ]] ; then
		# show root@ when we don't have colors
		PS1+='\u@\h \w \$ '
	else
		PS1+='\u@\h \w \$ '
	fi
fi

for sh in /etc/bash/bashrc.d/* ; do
	[[ -r ${sh} ]] && source "${sh}"
done

# Try to keep environment pollution down, EPA loves us.
unset use_color sh

#Setting some colors :)
red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m' # No Color

#oxiscripts update function
oxiscripts-update () {
	echo -e "${BLUE}--- oXiScripts autoupdate ---${NC}\n"
	if [[ ${EUID} != 0 ]] ; then
		echo -e "This function must be run as root. Sorry!"
		return
	fi

	echo -e "Downloading files: \c"
	wget -qq -r $OXIMIRROR -O /tmp/$(basename $OXIMIRROR)
	wget -qq -r $OXIMIRROR.md5 -O /tmp/$(basename $OXIMIRROR.md5)
	echo -e "Done"

	echo -e "MD5 Checksum: \c"
	if [ "$(md5sum /tmp/$(basename $OXIMIRROR) | awk '{print $1}')" = "$(cat /tmp/$(basename $OXIMIRROR).md5 | awk '{print $1}')" ]; then
		echo -e "${BLUE}OK${NC}"

		chmod +x /tmp/$(basename $OXIMIRROR)
		export $(egrep '^INSTALLOXIRELEASE=.*$' /tmp/$(basename $OXIMIRROR))
		echo -e "Actual Release:\t$OXIRELEASE | New Release:\t$INSTALLOXIRELEASE"

		if [ "$OXIRELEASE" -lt "$INSTALLOXIRELEASE" ]; then
			echo -e "${BLUE}--- Updating oXiScripts ---${NC}"
			/tmp/install.sh
			. /etc/oxiscripts/init.sh
		elif [ "$OXIRELEASE" -eq "$INSTALLOXIRELEASE" ]; then
			echo -e "${BLUE}You have already the newest version. :)${NC}"
			echo -e "If you like to reinstall oxiscripts, please run /tmp/$(basename $OXIMIRROR)"
		elif [ "$OXIRELEASE" -gt "$INSTALLOXIRELEASE" ]; then
			echo -e "Your mirror is old, or you have messed around with OXIRELEASE in /etc/oxiscripts/setup.sh"
		else
			echo -e "${RED}Some strange error occured:${NC} actual release [$OXIRELEASE], new release [$INSTALLOXIRELEASE]"
		fi
	else
		echo -e "${RED}Not OK!${NC}"
	fi
}

#oxiscripts set function
oxiscripts-set () {
	. /etc/oxiscripts/setup.sh

	if [[ ${EUID} != 0 ]] ; then
		echo -e "This function must be run as root. Sorry!"
		return
	fi
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
}

oxiscripts-get () {
	. /etc/oxiscripts/setup.sh
	echo -e "ADMINMAIL\t$ADMINMAIL"
	echo -e "BACKUPDIR\t$BACKUPDIR"
	echo -e "DEBUG\t\t$DEBUG"
	echo -e "SCRIPTSDIR\t$SCRIPTSDIR"
	echo -e "OXIMIRROR\t$OXIMIRROR"
}

oxireplace () {
	if [ -z "$3" ]; then
		echo -e "Please specify at lease 3 options! (file from to)"
	else
		TFILE=sed-tmp-$(date +%s)
		sed "s/$1/$2/g" $3 > /tmp/$TFILE
		cat /tmp/$TFILE > $3
		rm /tmp/$TFILE
	fi
}

# Try to keep environment pollution down, EPA loves us.
unset use_color safe_term match_lhs

# changes made by oxi

## VirtualBox stuff
#oxivbox-addonsupdate
oxivbox-addonsupdate () {
	if [ "$(uname -m)" = "i686" ];
	then
		MTYPE="x86"
	elif [ "$(uname -m)" = "x86_64" ];
	then
		MTYPE="amd64"
	fi
	echo -e "Machine type: $MTYPE"

	if [ -n "$(which apt-get)" ]; then
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

if [ ! -z "$(which VBoxManage)" ];
then
	. /etc/oxiscripts/virtualbox.sh
fi


# Load variables
if [ -f $SCRIPTDIR/init.sh ];
then
    . $SCRIPTDIR/init.sh
fi

# Add scripts dir to $PATH
if [ -e $HOME/scripts/ ];
then
	PATH=${PATH}:$HOME/scripts/
fi
if [ -e $HOME/bin/ ];
then
    PATH=${PATH}:$HOME/bin/
fi

if [ -f $SCRIPTDIR/checkfreespace.sh ];
then
	alias oxi_checkfreespace='$SCRIPTDIR/checkfreespace.sh'
fi

if [ -f $SCRIPTDIR/checkhost.sh ];
then
        alias oxi_checkhost='$SCRIPTDIR/checkhost.sh'
fi

if [ -f $SCRIPTDIR/checkpartitions.sh ];
then
        alias oxi_checkpartitions='$SCRIPTDIR/checkpartitions.sh'
fi

if [ -f $SCRIPTDIR/cleanup.sh ];
then
        alias oxi_cleanup='$SCRIPTDIR/cleanup.sh'
fi

if [ -f $SCRIPTDIR/scanlan.sh ];
then
        alias oxi_scanlan='$SCRIPTDIR/scanlan.sh'
fi

if [ -f $SCRIPTDIR/shortbackup.sh ];
then
        alias oxi_shortbackup='$SCRIPTDIR/shortbackup.sh'
fi

if [ -f $SCRIPTDIR/sync.sh ];
then
        alias oxi_sync='$SCRIPTDIR/sync.sh'
fi

if [ -f $SCRIPTDIR/sysmaint.sh ];
then
        alias oxi_sysmaint='$SCRIPTDIR/sysmaint.sh'
fi

# expanding bash history size
export HISTSIZE=10000

#How to init me (put it in your ~/.bashrc)
#
#if [ -f $HOME/scripts/init.sh ]; then
#       . $HOME/scripts/init.sh
#fi
