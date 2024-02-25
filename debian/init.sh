#!/bin/bash
# Debian init script

# Load gentoo like PS1

# Change the window title of X terminals
case ${TERM} in
        xterm*|rxvt*|Eterm|aterm|kterm|gnome*)
                PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/$HOME/~}\007"'
                ;;
        screen)
                PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/$HOME/~}\033\\"'
                ;;
esac

use_color=false

# Set colorful PS1 only on colorful terminals.
# dircolors --print-database uses its own built-in database
# instead of using /etc/DIR_COLORS.  Try to use the external file
# first to take advantage of user additions.  Use internal bash
# globbing instead of external grep binary.
safe_term=${TERM//[^[:alnum:]]/?}   # sanitize TERM
match_lhs=""
[[ -f ~/.dir_colors   ]] && match_lhs="${match_lhs}$(<~/.dir_colors)"
[[ -f /etc/DIR_COLORS ]] && match_lhs="${match_lhs}$(</etc/DIR_COLORS)"
[[ -z ${match_lhs}    ]] \
        && match_lhs=$(dircolors --print-database)
[[ $'\n'${match_lhs} == *$'\n'"TERM "${safe_term}* ]] && use_color=true

if ${use_color} ; then
        # Enable colors for ls, etc.  Prefer ~/.dir_colors #64489
                if [[ -f ~/.dir_colors ]] ; then
                        eval $(dircolors -b ~/.dir_colors)
                elif [[ -f /etc/DIR_COLORS ]] ; then
                        eval $(dircolors -b /etc/DIR_COLORS)
                fi

        if [[ ${EUID} == 0 ]] ; then
                PS1='\[\033[01;31m\]\h\[\033[01;34m\] \W \$\[\033[00m\] '
        else
                PS1='\[\033[01;32m\]\u@\h\[\033[01;34m\] \w \$\[\033[00m\] '
                # PS1='\[\033[01;32m\]\u@\h\[\033[01;34m\] \w \[\`if [[ \$? = "0" ]]; then echo '\e[32m=\)\e[0m'; else echo '\e[31m=\(\e[0m' ; fi\`\] \$\[\033[00m\] '
        fi

        alias ls='ls --color=auto'
        alias grep='grep --colour=auto'
else
        if [[ ${EUID} == 0 ]] ; then
                # show root@ when we don't have colors
                PS1='\u@\h \W \$ '
        else
                PS1='\u@\h \w \$ '
        fi
fi

# root only functions
if [[ $EUID -eq 0 ]];
then
	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade"
	ox-root-upgrade () {
		if [ "$1" == "--help" ]; then
			ox-root-upgrade-1 || exit 1
			ox-root-upgrade-2 || exit 2
			return 0
		fi
		apt-get upgrade
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade-2"
	ox-root-upgrade-2 () {
		if [ "$1" == "--help" ]; then
			echo "apt-get upgrade"
			return 0
		fi
		apt-get upgrade
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade-1"
	ox-root-upgrade-1 () {
		if [ "$1" == "--help" ]; then
			echo "apt-get update"
			return 0
		fi
		apt-get update
	}
fi
