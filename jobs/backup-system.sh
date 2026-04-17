#!/bin/bash
. /etc/oxiscripts/backup.sh

# backup list of installed packages
/usr/bin/dpkg --get-selections > /tmp/dpkg-selections
backup /tmp/dpkg-selections system
rm /tmp/dpkg-selections

# Mount /boot before backup?
needed="$(grep "/boot" /etc/fstab | grep -Ev "^#.*/boot.*" | awk '{ print $2 }')"
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
BACKUP_OPTIONS="--exclude=/boot/grub/grubenv" backup /boot system
if [ "$mountme" == "1" ]; then umount /boot; fi

# Backup Raspberry Pi firmware config if present
if [ -f /boot/firmware/config.txt ]; then
	backup /boot/firmware/config.txt system
fi

# Backup the entire /etc .. like magic ;)
backup /etc system

# Backup cron tabs if existent
if [ -d /var/spool/cron/ ];
then
	backup /var/spool/cron cron
fi
