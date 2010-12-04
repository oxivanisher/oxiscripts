#!/bin/bash
# Gentoo init script

# root only functions
if [[ $EUID -eq 0 ]];
then
	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade"
	function ox-root-upgrade {
		if [ "$1" == "--help" ]; then
			echo "emerge --sync && emerge --update --deep --newuse world -av"
			return 0
		fi
		ox-root-upgrade-1
		ox-root-upgrade-2
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade-2"
	function ox-root-upgrade-2 {
		if [ "$1" == "--help" ]; then
			echo "emerge --update --deep --newuse world -av"
			return 0
		fi
		emerge --update --deep --newuse world -av
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade-1"
	function ox-root-upgrade-1 {
		if [ "$1" == "--help" ]; then
			echo "emerge --sync"
			return 0
		fi
		emerge --sync
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-genkernel"
	function ox-root-genkernel {
		if [ "$1" == "--help" ]; then
			echo "create new kernel image"
			return 0
		fi

		/etc/oxiscripts/gentoo/gk.sh ${@}
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-clean"
	function ox-int-getsize {
		echo $(du -sh $1 | awk '{print $1}')
	}
	function ox-root-clean {
		if [ "$1" == "--help" ]; then
			echo "clear temporary system dirs"
			return 0
		fi
		DIRS="/var/tmp/portage"
		for DIR in $DIRS;
		do
			BEFORE=$(ox-int-getsize "$DIR")
			rm -rf $1/*
			AFTER=$(ox-int-getsize "$DIR")
			echo "Cleared $1 ($BEFORE -> $AFTER)"
		done
	}



fi
