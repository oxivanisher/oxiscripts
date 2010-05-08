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
##[ -z "$PS1" ] && return


##. /etc/oxiscripts/setup.sh

function oxivbox-get-vms {
	for USER in $(ls /home);
	do
		for VM in $(ls -1 --color=never /home/$USER/.VirtualBox/Machines);
		do
			echo -e "$USER\t$VM"
		done
	done
}

function oxivbox-get-running-vms {
	ps aux | grep virtualbox/VBoxHeadless | grep -v grep | awk '{print $1"\t"$NF}'
}

function oxivbox-start-vm {
	mycount=0
	for VM in $(find /home -name $1 -type d);
	do
		mycount=$(($mycount +1))
		vmname=$(echo $VM | awk -F/ '{print $NF}')
		myuser=$(echo $VM | awk -F/ '{print $3}')
		echo -e "Starting VM as $myuser: $VM"
		if [[ $EUID -ne 0 ]]; then
			if [[ "$myuser" == "$(whoami)"  ]]; then
				myuser=$(whoami)
				$(which screen) -dmS $vmname-$myuser $(which VBoxHeadless) -s $vmname
			fi
		else
			su $myuser -c "$(which screen) -dmS $vmname-$myuser $(which VBoxHeadless) -s $vmname" 
		fi
	done

	if [ "$mycount" = "0" ];
	then
		echo -e "No VMS found with the name: $1"
	fi
}

function oxivbox-stop-vm {
    mycount=0
    for VM in $(find /home -name $1 -type d);
    do
        mycount=$(($mycount +1))
        vmname=$(echo $VM | awk -F/ '{print $NF}')
        myuser=$(echo $VM | awk -F/ '{print $3}')
        echo -e "Stopping VM as $myuser: $VM"
        if [[ $EUID -ne 0 ]]; then
            if [[ "$myuser" == "$(whoami)"  ]]; then
                myuser=$(whoami)
                $(which screen) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname acpipowerbutton
            fi
        else
            su $myuser -c "$(which screen) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname acpipowerbutton" 
        fi
    done

    if [ "$mycount" = "0" ];
    then
        echo -e "No VMS found with the name: $1"
   fi

}

function oxivbox-reset-vm {
    mycount=0
    for VM in $(find /home -name $1 -type d);
    do
        mycount=$(($mycount +1))
        vmname=$(echo $VM | awk -F/ '{print $NF}')
        myuser=$(echo $VM | awk -F/ '{print $3}')
        echo -e "Starting VM as $myuser: $VM"
        if [[ $EUID -ne 0 ]]; then
            if [[ "$myuser" == "$(whoami)"  ]]; then
                myuser=$(whoami)
                $(which screen) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname reset
            fi
        else
            su $myuser -c "$(which screen) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname reset" 
        fi
    done

    if [ "$mycount" = "0" ];
    then
        echo -e "No VMS found with the name: $1"
   fi

}

function oxivbox-kill-vm {
    mycount=0
    for VM in $(find /home -name $1 -type d);
    do
        mycount=$(($mycount +1))
        vmname=$(echo $VM | awk -F/ '{print $NF}')
        myuser=$(echo $VM | awk -F/ '{print $3}')
        echo -e "Starting VM as $myuser: $VM"
        if [[ $EUID -ne 0 ]]; then
            if [[ "$myuser" == "$(whoami)"  ]]; then
                myuser=$(whoami)
                $(which screen) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname poweroff
            fi
        else
            su $myuser -c "$(which screen) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname poweroff"
        fi
    done

    if [ "$mycount" = "0" ];
    then
        echo -e "No VMS found with the name: $1"
   fi

}



#oxivbox-addonsisoupdate
function oxivbox-addonsisoupdate {
	BACKUPIFS=$IFS
	IFS=$'\n'
	echo -e "Searching for VM's"
	for VM in $(oxivbox-get-vms);
	do
		myuser=$(echo $VM | awk '{print $1}')
		myvm=$(echo $VM | awk '{print $2}')
		echo -e "\tChecking ($myuser) $myvm: \c"
		mytest=$(su -l $myuser -c "VBoxManage showvminfo $myvm --machinereadable" | grep dvd | grep /usr/share/virtualbox/VBoxGuestAdditions.iso)
		if [ -n "$mytest" ];
		then
			echo -e "Guest Additions mounted! Unmounting..."
			output=$(su -l $myuser -c "VBoxManage controlvm $myvm dvdattach none")
		else
			echo -e "Guest Additions not mounted"
		fi
	done
	IFS=$BACKUPIFS

	for USER in $(find /home -name .VirtualBox | awk -F/ '{print $3}');
	do
		echo -e "Closing medium for user: $USER"
		output=$(su -l $USER -c "VBoxManage closemedium dvd /usr/share/virtualbox/VBoxGuestAdditions.iso")
	done

	mv /usr/share/virtualbox/VBoxGuestAdditions.iso /usr/share/virtualbox/VBoxGuestAdditions.iso.old
	VBOXVER=$(VBoxManage | head -n 1 | grep -Eo '[0-9].*')
	echo -e "Fetching actual ISO..."
	wget --progress=dot:mega -O /usr/share/virtualbox/VBoxGuestAdditions.iso http://download.virtualbox.org/virtualbox/$VBOXVER/VBoxGuestAdditions_$VBOXVER.iso

    for USER in $(find /home -name .VirtualBox | awk -F/ '{print $3}');
    do
        echo -e "Opening medium for user: $USER"
        output=$(su -l $USER -c "VBoxManage openmedium dvd /usr/share/virtualbox/VBoxGuestAdditions.iso")
    done
	
   	BACKUPIFS=$IFS
	IFS=$'\n'
 	echo -e "Searching for VM's"
    for VM in $(oxivbox-get-vms);
    do
        myuser=$(echo $VM | awk '{print $1}')
        myvm=$(echo $VM | awk '{print $2}')
		echo -e "\tMounting Guest Additions on ($myuser) $myvm"
		output=$(su -l $myuser -c "VBoxManage controlvm $myvm dvdattach /usr/share/virtualbox/VBoxGuestAdditions.iso")
    done
	IFS=$BACKUPIFS
}

