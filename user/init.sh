#!/bin/bash
# User init script

# wrapper for scripts
ox-usr-checksite () {
	/etc/oxiscripts/user/checksite.sh ${@}
}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-tool-replace"
ox-tool-replace () {
	if [ "$1" == "--help" ]; then
		echo "replace in FILE SEARCH REPLACE"
		return 0
	fi

	if [ -z "$3" ]; then
		echo -e "Please specify at lease 3 options! (file from to)"
	else
		TFILE=sed-tmp-$(date +%s)
		sed "s/$1/$2/g" $3 > /tmp/$TFILE
		cat /tmp/$TFILE > $3
		rm /tmp/$TFILE
	fi
}
