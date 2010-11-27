#!/bin/bash
# Gentoo init script

# root only functions
if [[ $EUID -eq 0 ]];
then
	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-sys-upgrade"
	function ox-sys-upgrade {
		if [ "$1" == "--help" ]; then
			echo "emerge --update --deep --newuse world -av"
			return 0
		fi
		emerge --update --deep --newuse world -av
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-sys-update"
	function ox-sys-update {
		if [ "$1" == "--help" ]; then
			echo "emerge --sync"
			return 0
		fi
		emerge --sync
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-sys-genkernel"
	function ox-sys-genkernel {
		if [ "$1" == "--help" ]; then
			echo "create new kernel image"
			return 0
		fi

		/etc/oxiscripts/gentoo/gk.sh ${@}
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-sys-clean"
	function ox-int-getsize {
		echo $(du -sh $1 | awk '{print $1}')
	}
	function ox-sys-clean {
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