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
fi