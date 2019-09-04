#!/bin/bash

# This script must be run on a Virtual Terminal; some of the features here require an active
# session and user to work correctly with all configurations.
# (Including my special one)

# Please ensure that you have logged out of all user sessions before using this script;
# this is to ensure that there are no remaining X servers that can disrupt the container's own X server (i.e. use /dev/dri/card0, /dev/fb0, etc)
# You don't have to kill your display/login manager before this script; it'll do it for you.

# Once again, I am not responsible for anything that happens from executing this script. Hopefully, the script is smart enough to figure out problems.

# The script will attempt to log the user out via kill once it exits.
# PLEASE RUN THIS SCRIPT LIKE THIS: sudo ./desktop_enter_vt.sh CONTAINER_NAME && logout
# This is important because the virtual terminal is logged in as the user; 
# making it very dangerous to allow tom dick & harry to CTRL+C and get away with it. 

# The script will disable CTRL+Z, and will hook CTRL+C to a compulsary logout function. Hopefully this will prevent people with direct access to your laptop from getting to your user account.

### Your Login Manager's start/stop commands
LOGIN_MANAGER_START="service gdm3 start"
LOGIN_MANAGER_STOP="service gdm3 stop"

### Pre-begin, post-begin, pre-child and post-child script hooks
PRE_BEGIN_HOOK=""
POST_BEGIN_HOOK=""
PRE_CHILD_HOOK=""
POST_CHILD_HOOK=""

### Executable definitions (Generally unchanged)
BASH="/bin/bash"
ECHO="/bin/echo -e"
LXC="/usr/bin/lxc"
TOUCH="/usr/bin/touch"
HEAD="/usr/bin/head"
PKILL="/usr/bin/pkill"
GREP="/bin/grep"

CONTEXT_CONTAINER=""

### Functions
modules() { # modify this function based on the modules you want to run.

	# BRIGHTNESS MODULE: Allow usage of brightness keys
	./modules/brightness.sh &	

	# PULSEAUDIO MODULE: Required if you are planning to use sound within your container.
	./modules/pulseaudio.sh $CONTEXT_CONTAINER &
}

begin() {
	RES="$(tty)"
	EXPR="/dev/tty"

	if [[ "$RES" =~ "$EXPR" ]]; then
		:
	else
		$ECHO "The script must be run in a Virtual Terminal."
		exit 1
	fi

	set -e
	trap 'cleanup' 0
	trap '' TSTP # don't allow CTRL+Z

	if [[ "$PRE_BEGIN_HOOK" != "" ]]; then
		$ECHO "Running pre-begin hook..."
		$PRE_BEGIN_HOOK
	fi

	$ECHO "Checking if $1 exists..."
	state="$($LXC ls --format csv -c s $1)"

	if [[ "$state" == "" ]]; then
		$ECHO "The container does not exist. Quitting..."
		exit 2
	fi

	CONTEXT_CONTAINER=$1

	$ECHO "Stopping the container if necessary..."
	if [[ "$state" != "STOPPED" ]]; then
		$LXC stop -f $1
	fi

	$ECHO "Gracefully stopping host's login manager..."
	$SUDO $LOGIN_MANAGER_STOP
	sleep 10

	$ECHO "Starting the container..."
	$LXC start $1
	sleep 30

	$ECHO "Chmodding all video cards to group 44"
	$LXC exec $1 -- bash -c "ls /dev/dri/card* | xargs sudo chgrp 44"

	$ECHO "Commanding the container to start its display manager..."
	$LXC exec $1 -- sudo service lightdm start

	modules

	sleep infinity # wait for the user to quit
}

cleanup() {
	set +e
	trap disappear 0
	if [[ "$POST_CHILD_HOOK" != "" ]]; then
		$ECHO "Running post-child hook"
		$POST_CHILD_HOOK
	fi

	$ECHO "Child cleaning up now..."

	$ECHO "Gracefully stopping the container's display manager..."
	$LXC exec $CONTEXT_CONTAINER -- sudo service lightdm stop

	$ECHO "Restarting host's login manager..."
	$LOGIN_MANAGER_START

	$ECHO "All tasks complete."
	disappear
}

disappear() {
	TTY=$(tty | grep -oP "/dev/\Ktty[0-9]+") 
	$PKILL -9 -t $TTY # effectively logs the user out of the vt
}

usage() {
	$ECHO "Usage: $0 CONTAINER_NAME"
	$ECHO "Usage: $0 --clean CONTAINER_NAME"
	exit 1
}

if [[ $EUID -ne 0 ]]; then
	$ECHO "Root is required for the script to run."
	exit 1
fi

case $1 in
	"--clean") 
		if [[ "$2" == "" ]]; then
			usage
		fi	

		CONTEXT_CONTAINER=$2
		cleanup $2 ;;
	"") usage ;;
	*) begin $1
esac
