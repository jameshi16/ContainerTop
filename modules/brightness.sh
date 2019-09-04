#!/bin/bash
# A script that monitors the brightness keys and changes the brightness accordingly.
# Doing so prevent containers from having too much access to the host's devices.

# Superuser permissions are required.

# Edit this to adjust the interval
interval=375

EVTEST='/usr/bin/evtest'
device='/dev/input/eventZ'
event_up='*code 225 (KEY_BRIGHTNESSUP), value 1*'
event_down='*code 224 (KEY_BRIGHTNESSDOWN), value 1*'
intel_backlight='/sys/class/backlight/intel_backlight/brightness'

sudo $EVTEST "$device" | while read line; do
	case $line in
		$event_up) echo $(( $(cat /sys/class/backlight/intel_backlight/brightness) + $interval )) | sudo tee $intel_backlight > /dev/null 2>&1 ;;
		$event_down) echo $(( $(cat /sys/class/backlight/intel_backlight/brightness) - $interval )) | sudo tee $intel_backlight > /dev/null 2>&1 ;;
	esac
done
