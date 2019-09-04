#!/bin/bash
# A script that launches a system-level pulseaudio server, and enables the TCP module.
# Please pass in the container name as one of the arguments to use the script.
# WARNING: Please use a firewall to ensure no one else but the container can access your port, although the pulseaudio server is secured with a cookie.

# Superuser permissions are required.

### Executables
PULSEAUDIO="/usr/bin/pulseaudio"
PACTL="/usr/bin/pactl"
ECHO="/bin/echo -e PulseAudio -- "
LXC="/usr/bin/lxc"
SUDO="/usr/bin/sudo"

### Pulse cookie path used by PulseAudio --system=TRUE
PULSE_COOKIE="/var/run/pulse/.config/pulse/cookie"

if [[ "$1" == "" ]]; then
	$ECHO "Please pass in a container name!"
	exit 1
fi

EXISTS=$($LXC ls $1 --format csv -c n)
if [[ "$EXISTS" == "" ]]; then
       $ECHO "The container does not exist."	
       exit 1
fi

if [[ "$UID" != "0" ]]; then
	$ECHO "This script needs to be run with superuser privileges."
	exit 1
fi

$ECHO "Starting PulseAudio in the background..."
$SUDO $PULSEAUDIO --system=TRUE & # okay look, I can use --daemonize here, but I want pulseaudio to quit after the user logs out; meaning that running it as a background job is a better idea.
sleep 5 # wait for pulseaudio to settle
$SUDO PULSE_COOKIE=$PULSE_COOKIE $PACTL load-module module-native-protocol-tcp # might want to change the path if needed
$SUDO $LXC file push $PULSE_COOKIE $1/home/ubuntu/pulse_cookie
$SUDO $LXC exec $1 -- sudo chmod 660 /home/ubuntu/pulse_cookie
$SUDO $LXC exec $1 -- sudo chown ubuntu /home/ubuntu/pulse_cookie
$SUDO $LXC exec $1 -- sudo chgrp ubuntu /home/ubuntu/pulse_cookie

# all done
