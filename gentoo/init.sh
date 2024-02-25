#!/bin/bash
# Gentoo init script

# root only functions
if [[ $EUID -eq 0 ]];
then
	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade"
	ox-root-upgrade () {
		if [ "$1" == "--help" ]; then
			echo "ox-root-upgrade-1 && ox-root-upgrade-2"
			return 0
		fi
		ox-root-upgrade-1 || exit 1
		ox-root-upgrade-2 || exit 1
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade-2"
	ox-root-upgrade-2 () {
		if [ "$1" == "--help" ]; then
			echo "emerge --update --deep --newuse world -av"
			return 0
		fi
		ox-zint-run emerge --update --deep --newuse world -av
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-upgrade-1"
	ox-root-upgrade-1 () {
		if [ "$1" == "--help" ]; then
			echo "emerge --sync"
			return 0
		fi
		ox-zint-run emerge --sync
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-optimize"
	ox-root-optimize () {
		if [ "$1" == "--help" ]; then
			echo "emerge --depclean && revdep-rebuild"
			return 0
		fi
		ox-zint-run emerge --depclean
		ox-zint-run revdep-rebuild
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-genkernel"
	ox-root-genkernel () {
		if [ "$1" == "--help" ]; then
			echo "create new kernel image"
			return 0
		fi
		ox-zint-run /etc/oxiscripts/gentoo/gk.sh ${@}
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-clean"
#	ox-zint-getsize () {
#		echo $(du -sh $1 | awk '{print $1}')
#	}
	ox-root-clean () {
		if [ "$1" == "--help" ]; then
			echo "clear temporary system dirs (eclean -i distfiles)"
			return 0
		fi
#		DIRS="/var/tmp/portage"
#		for DIR in $DIRS;
#		do
#			BEFORE=$(ox-zint-getsize "$DIR")
#			rm -rf $1/*
#			AFTER=$(ox-zint-getsize "$DIR")
#			echo "Cleared $1 ($BEFORE -> $AFTER)"
#		done
		ox-zint-run eclean -i distfiles
	}

	export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-root-maintenance"
	ox-root-maintenance () {
		if [ "$1" == "--help" ]; then
			echo "ox-root-upgrade && ox-root-optimize && ox-root-clean"
			return 0
		fi
		ox-root-upgrade
		ox-root-optimize
		ox-root-clean
	}


fi
