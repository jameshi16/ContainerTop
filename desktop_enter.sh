#!/bin/bash

# WARNING: INCOMPLETE SCRIPT
# If you don't have any special requirements, this script _may_ work.
# However, my current (secret) setup required special proceedures that would otherwise break this script,
# so I didn't complete it in the end (note: I spent like 7 hours trying to fit my setup here)

# This script will switch the host to the containerized desktop.
# This should be executed on the user's logged in session
# If any steps within this script fails, GDM is restarted, and the user will be prompted to login again.

### Your Login Manager's logout command
LOGOUT_COMMAND="gnome-session-quit --logout --no-prompt"

### Your Login Manager's start/stop commands
LOGIN_MANAGER_START="service gdm3 start"
LOGIN_MANAGER_STOP="service gdm3 stop"

### Pre-begin, post-begin, pre-child and post-child script hooks
PRE_BEGIN_HOOK="" 
POST_BEGIN_HOOK=""
PRE_CHILD_HOOK=""
POST_CHILD_HOOK=""

### Logout hook
LOGOUT_HOOK="" # this will run before the logout command.

### Definitions (Generally unchanged)
BASH="/bin/bash"
ECHO="/bin/echo -e"
LXC="/usr/bin/lxc"
RM="/bin/rm -vf"
SUDO="/usr/bin/sudo"
TOUCH="/usr/bin/touch"
OPENVT="/bin/openvt"
CHVT="/bin/chvt"
HEAD="/usr/bin/head"
NOHUP="/usr/bin/nohup"
SETSID="/usr/bin/setsid"
CUT="/usr/bin/cut"
GETENT="/usr/bin/getent"

MODULE_STRING="./modules/brightness.sh &"

LOGFILE=""
PIDFILE="/tmp/containertop.pid"

CONTEXT_CONTAINER=""
CONTEXT_TTY=$($HEAD "/sys/devices/virtual/tty/tty0/active")
CONTEXT_USERNAME=$($GETENT passwd "$UID" | $CUT -d: -f1)
CONTEXT_VT_REGEX="tty([0-9]+)"

if [[ $CONTEXT_TTY =~ $CONTEXT_VT_REGEX ]]; then
	CONTEXT_VT=${BASH_REMATCH[1]}
fi

### Functions
begin() {
	if [[ "$PRE_BEGIN_HOOK" != "" ]]; then
		$ECHO "Running pre-begin hook..."
		$PRE_BEGIN_HOOK
	fi

	$ECHO "Entering the container. This process may take up to a minute."
	$ECHO "While this process is occuring, your screen may flash; that is perfectly normal behaviour."

	$ECHO "\nChecking if $1 exists..."
	state="$($LXC ls --format csv -c s $1)"
	
	if [[ "$state" == "" ]]; then
		$ECHO "The container does not exist. Quitting..."
		exit 1
	fi

	$ECHO "\nStopping the container if necessary..."
	if [[ "$state" != "STOPPED" ]]; then
		$LXC stop -f $1
	fi

	$ECHO "\nLaunching current script as background task..."
	set +e
	trap : 0
	$SUDO $SETSID $OPENVT -- $BASH -c "$PWD/$0 child $1 $CONTEXT_VT"

	$ECHO "\n"
	$LOGOUT_HOOK
	set -e
	trap 'cleanup' 0
	$ECHO  "Logging out the user safely..."
	$LOGOUT_COMMAND
}

child() { #$1 is container name, $2 is the context virtual terminal	
	$ECHO "Child process starting, PID: $$"
	$ECHO $$ > $PIDFILE
	$ECHO "Wrote to PID file at: $PIDFILE"

	$ECHO "Waiting for logout (5 seconds) to complete..."
	sleep 5

	$ECHO "Switching the user back to this virtual terminal..."
	$CHVT $CONTEXT_VT

	if [[ "$PRE_CHILD_HOOK" != "" ]]; then
		$ECHO "Running pre-child hook..."
		$SUDO -u $USERNAME $PRE_CHILD_HOOK
	fi

	#set -e
	#trap 'child_cleanup' 0
	CONTEXT_CONTAINER=$1	

	$ECHO "Gracefully stopping host's login manager..."
	$LOGIN_MANAGER_STOP

	$ECHO "Starting the container..."
	$LXC start $1

	$ECHO "Commanding the container to start its display manager..."
	$LXC exec $CONTEXT_CONTAINER -- sudo service lightdm start

	#$ECHO "Loading modules..."	
	#$MODULES_STRING

	#set +e
	#trap : 0
}

child_cleanup() {
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

	$RM $PIDFILE
}

usage() {
	$ECHO "$0 - Switches to the desktop environment within a container."
	$ECHO "Usage: $0 CONTAINER_NAME"
}

cleanup() {	
	if [[ "$POST_BEGIN_HOOK" != "" ]]; then
		$ECHO "Running post-begin hook..."
		$POST_BEGIN_HOOK
	fi
	
	$ECHO "\nCleaning up now..."
}

### Common entrypoint for all modes
case $1 in
	"child") child $2 $3 ;;
	"")	usage ;;
	*) 
		trap 'cleanup' 0
		set -e
		begin $1
		trap : 0
		cleanup
		;;
esac
