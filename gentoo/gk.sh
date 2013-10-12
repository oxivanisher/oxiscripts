#!/bin/bash
# original by Pavol Dilung, Sicap Trainer
PATH=/bin:/usr/bin:/sbin:/usr/sbin

# A name that'll be appended to initramfs and kernel files
KERN_NAME="gk"
# A Default kernel config
KERN_CONF="/etc/kernels/linux-2.6"
# Default directory for initramfs overlay
GKERN_OVLDIR="/var/tmp/genkernel-overlay"
# User secified binaries that need to be present in initramfs
GKERN_OVLBINS="/sbin/udevd /sbin/udevadm /sbin/mkfs.ext4 /sbin/e2fsck /sbin/fsck.ext2 /sbin/fsck.ext3 /sbin/fsck.ext4"
# Userdefined genkernel arguments
GKERN_ARGS="--luks --menuconfig"
# Default genkernel arguments
GKERN_ARGS="${GKERN_ARGS} --kernname=${KERN_NAME:-unknown} --initramfs-overlay=${GKERN_OVLDIR} --no-ramdisk-modules --install"
# SPLASH Arguments
GKERN_SPLASH_ARGS="--splash=natural_gentoo"
# Genkernel command binary
GKERN_CMD=/usr/bin/genkernel


#
# Functions
#

usage() {
	echo "Usage: $(basename $0) <[-b|--build]|[-c|--clean]|[-p|--mrproper]>"
}

gk_get_libs() {
	local bins="${@}"
	local b=

	for b in ${bins}; do
		if [[ -f ${b} ]]; then
			ldd ${b} | awk '{ if (NF == 2) print $1; else if (NF == 4) print $3; }'
		fi
	done | sort -u
}

gk_make_overlay() {
	echo "Creating initramfs overlay"
	local bins="${@}"
	local b=
	local l=

	rm -rf ${GKERN_OVLDIR}
	install -d -o root -g root -m 0755 ${GKERN_OVLDIR}
	install -d -o root -g root -m 0755 ${GKERN_OVLDIR}/sbin
	install -d -o root -g root -m 0755 ${GKERN_OVLDIR}/bin
	install -d -o root -g root -m 0755 ${GKERN_OVLDIR}/lib

	for b in ${bins}; do
		[[ -f ${b} ]] && install -o root -g root -m 0755 ${b} ${GKERN_OVLDIR}${b}
	done

	for l in $(gk_get_libs ${bins}); do
		install -o root -g root -m 0755 ${l} ${GKERN_OVLDIR}/lib
	done
}

#
# Main
#
main() {
	local 
	# Exit with failure if no genkernel exists
	[[ ! -x ${GKERN_CMD} ]] && exit 1
	# Set umask(2) appropriately
	umask 0022

	case "${1}" in
		--build|-b)
		GKERN_ARGS="${GKERN_ARGS} --no-clean --no-mrproper"
		;;
		--clean|-b)
		GKERN_ARGS="${GKERN_ARGS} --no-clean --clean"
		;;
		--mrproper|-m)
		GKERN_ARGS="${GKERN_ARGS} --no-clean --mrproper"
		;;
		*)
		usage
		exit 1
		;;
	esac

	GKERN_ARGS="--symlink --kernel-config=${KERN_CONF} ${GKERN_ARGS}"
	gk_make_overlay ${GKERN_OVLBINS}
	echo "Starting genkernel"
	time ${GKERN_CMD} ${GKERN_ARGS} ${GKERN_SPLASH_ARGS} all
}

main "${1}"
