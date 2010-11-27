#!/bin/bash
#
# This file is sourced by all *interactive* bash shells on startup,
# including some apparently interactive shells such as scp and rcp
# that can't tolerate any output.  So make sure this doesn't display
# anything or bad things will happen !


# SETUP!

# Test for an interactive shell.  There is no need to set anything
# past this point for scp and rcp, and it's important to refrain from
# outputting anything in those cases.
[ -z "$PS1" ] && return

# Here we go!
. /etc/oxiscripts/functions.sh

# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
shopt -s checkwinsize

# Enable history appending instead of overwriting.  #139609
shopt -s histappend

# Get LSB ID and load distribution specific init.sh
LSBID="unsupported"
case "$(lsb_release -is)" in
	Debian|Ubuntu)
		export LSBID="debian"
	;;
	Gentoo)
		export LSBID="gentoo"
	;;
	#RedHatEnterpriseServer|CentOS)
	#LSBID="redhat"
	#;;
esac
# Load distribution based functions
if [ "$LSBID" != "" ];
then
	if [ -f "/etc/oxiscripts/$LSBID/init.sh" ];
	then
		. /etc/oxiscripts/$LSBID/init.sh
	fi
else
	unset LSBID
fi


#Setting some colors :)
red='\e[0;31m'
RED='\e[1;31m'
blue='\e[0;34m'
BLUE='\e[1;34m'
cyan='\e[0;36m'
CYAN='\e[1;36m'
NC='\e[0m' # No Color

# Add scripts dir to $PATH
if [ -e $HOME/scripts/ ];
then
	PATH=${PATH}:$HOME/scripts/
fi
if [ -e $HOME/bin/ ];
then
    PATH=${PATH}:$HOME/bin/
fi
if [ -e /etc/oxiscripts/user/ ];
then
    PATH=${PATH}:/etc/oxiscripts/user/ 
fi

unset -f ox-int-register-function
# expanding bash history size
export HISTSIZE=10000
# Try to keep environment pollution down, EPA loves us.
unset use_color safe_term match_lhsnuf

alias ll="ls -lha"