#!/bin/bash

#. /etc/oxiscripts/functions.sh

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-vbox-get-vms"
function ox-vbox-get-vms {
	if [ "$1" == "--help" ]; then
		echo "placeholder"
		return 0
	fi
	for USER in $(ls /home);
	do
		for VM in $(ls -1 --color=never /home/$USER/.VirtualBox/Machines);
		do
			echo -e "$USER\t$VM"
		done
	done
}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-vbox-get-running-vms"
function ox-vbox-get-running-vms {
	if [ "$1" == "--help" ]; then
		echo "placeholder"
		return 0
	fi
	ps aux | grep virtualbox/VBoxHeadless | grep -v grep | awk '{print $1"\t"$NF}'
}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-vbox-start-vm"
function ox-vbox-start-vm {
	if [ "$1" == "--help" ]; then
		echo "placeholder"
		return 0
	fi
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
				$( which screen 2>/dev/null) -dmS $vmname-$myuser $( which VBoxHeadless 2>/dev/null ) -s $vmname
			fi
		else
			su $myuser -c "$( which screen 2>/dev/null) -dmS $vmname-$myuser $( which VBoxHeadless 2>/dev/null ) -s $vmname" 
		fi
	done

	if [ "$mycount" = "0" ];
	then
		echo -e "No VMS found with the name: $1"
	fi
}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-vbox-stop-vm"
function ox-vbox-stop-vm {
	if [ "$1" == "--help" ]; then
		echo "placeholder"
		return 0
	fi
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
                $( which screen 2>/dev/null) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname acpipowerbutton
            fi
        else
            su $myuser -c "$( which screen 2>/dev/null) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname acpipowerbutton" 
        fi
    done

    if [ "$mycount" = "0" ];
    then
        echo -e "No VMS found with the name: $1"
   fi

}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-vbox-reset-vm"
function ox-vbox-reset-vm {
	if [ "$1" == "--help" ]; then
		echo "placeholder"
		return 0
	fi
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
                $( which screen 2>/dev/null) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname reset
            fi
        else
            su $myuser -c "$( which screen 2>/dev/null) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname reset" 
        fi
    done

    if [ "$mycount" = "0" ];
    then
        echo -e "No VMS found with the name: $1"
   fi

}

export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-vbox-kill-vm"
function ox-vbox-kill-vm {
	if [ "$1" == "--help" ]; then
		echo "placeholder"
		return 0
	fi
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
                $( which screen 2>/dev/null) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname poweroff
            fi
        else
            su $myuser -c "$( which screen 2>/dev/null) -dmS $vmname-$myuser-kill $(which VBoxManage) controlvm $vmname poweroff"
        fi
    done

    if [ "$mycount" = "0" ];
    then
        echo -e "No VMS found with the name: $1"
   fi

}



#ox-vbox-addonsisoupdate
export OXISCRIPTSFUNCTIONS="$OXISCRIPTSFUNCTIONS:ox-vbox-addonsisoupdate"
function ox-vbox-addonsisoupdate {
	if [ "$1" == "--help" ]; then
		echo "placeholder"
		return 0
	fi
	BACKUPIFS=$IFS
	IFS=$'\n'
	echo -e "Searching for VM's"
	for VM in $(ox-vbox-get-vms);
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
    for VM in $(ox-vbox-get-vms);
    do
        myuser=$(echo $VM | awk '{print $1}')
        myvm=$(echo $VM | awk '{print $2}')
		echo -e "\tMounting Guest Additions on ($myuser) $myvm"
		output=$(su -l $myuser -c "VBoxManage controlvm $myvm dvdattach /usr/share/virtualbox/VBoxGuestAdditions.iso")
    done
	IFS=$BACKUPIFS
}

