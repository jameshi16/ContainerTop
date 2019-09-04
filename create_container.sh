#!/bin/bash

# Creates a container with a desktop environment.
# By default, the container will use Ubuntu 18.04, with the ubuntu-mate-desktop package installed.
# This will take a while, and will take about ~6GB of space.

### Executable options (modify this)
LXC="/usr/bin/lxc"
IMAGE="ubuntu:18.04"
DESKTOP_ENV_PACKAGE="ubuntu-mate-desktop"
LOGIN_MGR_PACKAGE="lightdm" # at the moment, only lightdm has a supported script
GREETER_PACKAGE="unity-greeter" # the default slick-greeter doesn't work.
DRIVERS="nvidia-driver-XXX xserver-xorg-input-libinput xserver-xorg-input-synaptics xserver-xorg-input-evdev xserver-xorg-input-kbd" # upgrade the nvidia driver here, if wanted.
KEYBOARD="/dev/input/eventX" # use evtest to figure out which devices correspond to what
MOUSE="/dev/input/eventY"

### Package manager commands. Please note I'm assuming your package manager can handle dependencies.
PACKAGE_MANAGER_UPDATE="sudo apt-get -qq update" # prepend a "sudo" if the command requires it
PACKAGE_MANAGER_UPGRADE="sudo apt-get -qq full-upgrade"
PACKAGE_MANAGER_INSTALL="sudo apt-get -y install"

### Options
NETWORK=""
STORAGE=""
GPU=0
IGNORE=0

### Executable constants (this is usually constant)
ECHO="/bin/echo -e"

### Functions
create() {
	set -e
	trap 'error' 0

	if [[ $IGNORE -eq 0 ]]; then
		$ECHO "Checking to make sure $1 does not already exist..."

		RESULT=$($LXC ls $1 --format csv -c n)
		if [[ "$RESULT" == "$1" ]]; then
			$ECHO "The container, $1 already exists."
		fi

		$ECHO "Creating the container..."

		LXC_OPTION=""
		if [[ "$NETWORK" != "" ]]; then
			LXC_OPTION="$LXC_OPTION -n $NETWORK"
		fi

		if [[ "$STORAGE" != "" ]]; then
			LXC_OPTION="$LXC_OPTION -s $STORAGE"
		fi

		$LXC launch $IMAGE $1 $LXC_OPTION
		sleep 10
	fi

	$ECHO "Updating package list within the container..."
	$LXC exec $1 -- $PACKAGE_MANAGER_UPDATE

	$ECHO "Upgrading all packages..."
       	$LXC exec $1 -- $PACKAGE_MANAGER_UPGRADE

	$ECHO "Installing lightdm and desktop environment (this will take a while)..."
	$LXC exec $1 -- $PACKAGE_MANAGER_INSTALL $DESKTOP_ENV_PACKAGE $LOGIN_MGR_PACKAGE $GREETER_PACKAGE

	$ECHO "Installing drivers..."
	$LXC exec $1 -- $PACKAGE_MANAGER_INSTALL $DRIVERS

	$ECHO "Copying over X11 scripts..."
	$LXC file push ./container_scripts/xorg.conf.intel $1/etc/X11/xorg.conf.intel
	
	if [[ $GPU -eq 1 ]]; then
		$LXC file push ./container_scripts/xorg.conf.nvidia $1/etc/X11/xorg.conf.nvidia
	fi

	if [[ "$LOGIN_MGR_PACKAGE" == "lightdm" ]]; then
		$ECHO "Copying over lightdm configuration files..."
		$LXC file push ./container_scripts/lightdm.conf $1/etc/lightdm/lightdm.conf
		$LXC file push ./container_scripts/50-greeter-wrapper.conf.intel $1/usr/share/lightdm/50-greeter-wrapper.conf.intel

		if [[ $GPU -eq 1 ]]; then
			$LXC file push ./container_scripts/50-greeter-wrapper.conf.nvidia $1/usr/share/lightdm/50-greeter-wrapper.conf.nvidia
		fi
	fi

	$ECHO "Finishing installation with Intel as default."
	$LXC exec $1 -- sudo cp /etc/X11/xorg.conf.intel /etc/X11/xorg.conf
	
	if [[ "$LOGIN_MGR_PACKAGE" == "lightdm" ]]; then
		$ECHO "Finishing installation with Intel as default. - LightDM"
		$LXC exec $1 -- sudo cp /usr/share/lightdm/50-greeter-wrapper.conf.intel /usr/share/lightdm/50-greeter-wrapper.conf
	fi

	$ECHO "Configuring the container..."
	$LXC config device add $1 Keyboard unix-char path=$KEYBOARD gid=104
	$LXC config device add $1 Mouse unix-char path=$MOUSE gid=104
	$LXC config device add $1 fb0 unix-char path=/dev/fb0 gid=44
	$LXC config device add $1 gpu gpu
	$LXC config device add $1 card0 unix-char path=/dev/dri/card0 gid=44
	
	if [[ $GPU -eq 1 ]]; then
		$LXC config device add $1 card1 unix-char path=/dev/dri/card1 gid=44
	fi

	$LXC config device add $1 tty0 unix-char path=/dev/tty0 gid=5
	$LXC config device add $1 tty7 unix-char path=/dev/tty7 gid=5

	$ECHO "Disabling lightdm so it doesn't start on container boot..."
	$LXC exec $1 -- sudo systemctl disable lightdm
	
	$ECHO "Changing password for the default user..."
	$LXC exec $1 -- sudo passwd ubuntu

	$LXC stop $1

	$ECHO "All tasks complete. Container is ready for usage."
	set +e
	trap : 0
}

error() {
	$ECHO "An error has occured. The container is left intact for your inspection."
}

usage() {
	$ECHO "Usage: $0 CONTAINER_NAME [-s STORAGE_POOL] [-n NETWORK_INTERFACE] [-g]\n"
	$ECHO "-s\t\tThe LXD storage pool to use for this new container."
	$ECHO "-n\t\tThe LXD networking device to use for this new container."
	$ECHO "-g\t\tExternal GPU support"
	$ECHO "-h\t\tThis help screen"
	exit 1
}

### Actual script
case "$1" in
	"")
		usage
		;;
	*)
		CONTAINER_NAME=$1
		shift 1

		while getopts "n:s:g:i" opt; do
			case $opt in
				n)
					NETWORK=$OPTARG
					;;
				s)
					STORAGE=$OPTARG
					;;
				g)
					GPU=1
					;;
				i)
					IGNORE=1
					;;
			esac
		done

		create $CONTAINER_NAME
		;;
esac
