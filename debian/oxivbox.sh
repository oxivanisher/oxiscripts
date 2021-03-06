#! /bin/bash

### BEGIN INIT INFO
# Provides:          oxivbox
# Required-Start:    $local_fs $remote_fs vboxdrv
# Required-Stop:     $local_fs $remote_fs vboxdrv
# Should-Start:      $all
# Should-Stop:       $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/stop oxivbox
# Description:       Start/stop oxivbox
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin
CONFFILE=/etc/oxiscripts/oxivbox.conf

# log_daemon_msg() and log_progress_msg() isn't present in present in Sarge.
# Below is a copy of them from lsb-base 3.0-5, for the convenience of back-
# porters.  If the installed version of lsb-base provides these functions,
# they will be used instead.

log_daemon_msg () {
    if [ -z "$1" ]; then
        return 1
    fi

    if [ -z "$2" ]; then
        echo -n "$1:"
        return
    fi
    
    echo -n "$1: $2"
}

log_progress_msg () {
    if [ -z "$1" ]; then
        return 1
    fi
    echo -n " $@"
}

. /lib/lsb/init-functions
. /etc/oxiscripts/init.sh
. /etc/oxiscripts/virtualbox.sh

verify_superuser() {
	action=$1
	[ $EUID -eq 0 ] && return
	log_failure_msg "Superuser privileges required for the" \
			"\"$action\" action."
	exit 4
}

start() {
	mycount=0
	log_daemon_msg "oxivbox booting"

	lastuser=""
	for VM in $(cat /etc/oxiscripts/oxivbox.conf);
	do
		mycount=$(($mycount +1))
		vmname=$(echo $VM | awk -F/ '{print $NF}')
		myuser=$(echo $VM | awk -F/ '{print $3}')

		if [ ! "$myuser" = "$lastuser" ]; then
			log_progress_msg "($myuser)"
		fi
		
		lastuser=$myuser
		
		log_progress_msg "$vmname"
		if [[ $EUID -ne 0 ]]; then
			if [[ "$myuser" == "$(whoami)"  ]]; then
				myuser=$(whoami)
				$( which screen 2>/dev/null ) -dmS $vmname-$myuser $( which VBoxHeadless 2>/dev/null ) -s $vmname
			fi
		else
			su $myuser -c "$( which screen 2>/dev/null ) -dmS $vmname-$myuser $( which VBoxHeadless 2>/dev/null ) -s $vmname" 
		fi
	done

	if [ "$mycount" = "0" ];
	then
		log_progress_msg "No VMS found to autoboot."
	fi
	
	log_end_msg 0
}

stop() {
	log_daemon_msg "Stopping Virtual Machines"
	# killproc() doesn't try hard enough if the pid file is missing,
	# so create it is gone and the daemon is still running
#	killproc -p $PIDFILE /usr/bin/munin-node
	ret=$?
	# killproc() isn't thorough enough, ensure the daemon has been
	# stopped manually
	attempts=0
#	until ! pidofproc -p $PIDFILE $DAEMON >/dev/null; do
#		attempts=$(( $attempts + 1 ))
#		sleep 0.05
#		[ $attempts -lt 20 ] && continue
#		log_end_msg 1
#		return 1
#	done
	[ $ret -eq 0 ] && log_progress_msg "done"
	log_end_msg $ret
	return $ret
}

if [ "$#" -ne 1 ]; then
	log_failure_msg "Usage: /etc/init.d/oxivbox" \
			"{start|stop|restart|status}"
	exit 2
fi

case "$1" in
  start)
  	verify_superuser $1
  	start
	exit $?
	;;
  stop)
  	verify_superuser $1
  	stop
	exit $?
	;;
  restart)
  	verify_superuser $1
  	stop || exit $?
	start
	exit $?
	;;
  status)
  	pid=$(pidofproc -p $PIDFILE $DAEMON)
	ret=$?
	pid=${pid% } # pidofproc() supplies a trailing space, strip it
	if [ $ret -eq 0 ]; then
		log_success_msg "Munin-Node is running (PID: $pid)"
		exit 0
	elif [ $ret -eq 1 ] || [ $ret -eq 2 ]; then
		log_failure_msg "Munin-Node is dead, although $PIDFILE exists."
		exit 1
	elif [ $ret -eq 3 ]; then
		log_warning_msg "Munin-Node is not running."
		exit 3
	fi
	log_warning_msg "Munin-Node status unknown."
	exit 4
        ;;
  *)
	log_failure_msg "Usage: /etc/init.d/munin-node" \
			"{start|stop|restart|status}"
	exit 2
	;;
esac

log_failure_msg "Unexpected failure, please file a bug."
exit 1
