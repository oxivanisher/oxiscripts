#!/bin/bash
. /etc/oxiscripts/backup.sh

case "$(lsb_release -is)" in
	Debian|Ubuntu|Raspbian)
		LSBID="debian"
	;;
	Gentoo)
		LSBID="gentoo"
	;;
#		RedHatEnterpriseServer|CentOS)
#			LSBID="redhat"
#		;;
esac

#If we are on a debian based system, backup the installed packages
if [ "$LSBID" == "debian" ];
then
	# Debian systems backup

	# backup list of installed packages
	/usr/bin/dpkg --get-selections > /tmp/dpkg-selections
	backup /tmp/dpkg-selections system
	rm /tmp/dpkg-selections

elif [ "$LSBID" == "gentoo" ];
then
	# Gentoo systems backup

	# backup world file
	backup /var/lib/portage/world system

	# backup kernel config
	zcat /proc/config.gz > /tmp/kernel-config-$(uname -r)
	backup /tmp/kernel-config-$(uname -r) system
	rm /tmp/kernel-config-$(uname -r)
fi

# Mount /boot before backup?
needed="$(grep "/boot" /etc/fstab | egrep -v "^#.*/boot.*" | awk '{ print $2 }')"
already_mounted=$(grep /boot /etc/mtab)
if [ "$already_mounted" == "" ];
then
	if [ "$needed" != "" ];
	then
		mountme=1
	else
		mountme=0
	fi
fi

# backup /boot
if [ "$mountme" == "1" ]; then mount /boot; fi
backup /boot system
if [ "$mountme" == "1" ]; then umount /boot; fi

# Backup the entire /etc .. like magic ;)
backup /etc system

# Backup cron tabs if existent
if [ -d /var/spool/cron/ ];
then
	backup /var/spool/cron cron
fi
