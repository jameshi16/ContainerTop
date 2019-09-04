# ContainerTop

A bundle of scripts to create and switch to a desktop environment residing within a container, complete with native video acceleration and unprivileged goodness. Uses LXD as a backend.

Please check out the relevant [blog post entry](https://codingindex.xyz/2019/09/04/desktop-in-lxd-containers/) written for ContainerTop.

## Overview

ContainerTop is a solution to users who want to isolate, hardware specifications wise, identical-to-host workspaces from their hosts without resorting to heavy means like virtualization with GPU passthrough. 

ContainerTop is built without ID mapping and runs unprivileged, appealing to the privacy-oriented users, as there is no longer a risk of an escaping process escalating to a high enough permission to ruin files on the host, should such a container escape happen.

## Notice

Please note that I (James) am not responsible for anything that happens to your computer when you run these scripts; they don't do anything dangerous and can be reverted easily, provided the user knows exactly what they're doing.

Please be familiar with the [REISUB](https://en.wikipedia.org/wiki/Magic_SysRq_key) technique to reboot your computer should typical operations no longer work. You must also be familiar with terminal switching with the CTRL+ALT+F\<num\> key combinations.

Basic knowledge of Linux commands is recommended.

**YOU MUST READ THE SETTING UP SECTION. DO NOT RUN ANY SCRIPTS WITHOUT READING IT.**

## Requirements

The scripts are tested on a slightly off-average configuration of Ubuntu 18.04.3, but should still work on a typical installation of Ubuntu 18.04.3. As long as the scripts are edited correctly, they should work on other Linux distributions as well. Below are a list of commands required on the host for the core scripts to work, and their default paths:

- `lxc`, defaults to `/usr/bin/lxc`;
- `echo`, defaults to `/bin/echo`;
- `bash`, defaults to `/bin/bash`;
- `touch`, defaults to `/usr/bin/touch`;
- `head`, defaults to `/usr/bin/head`;
- `pkill`, defaults to `/usr/bin/pkill`;
- `grep`, defaults to `/bin/grep`.

The modules, which are all opt-out by default, uses these commands:
- `evtest`, defaults to `/usr/bin/evtest`, used by the brightness module;
- `pulseaudio`, defaults to `/usr/bin/pulseaudio`, used by the pulseaudio module;
- `pactl`, defaults to `/usr/bin/pactl`, used by the pulseaudio module;
- `echo`, defaults to `/bin/echo`, used by the pulseaudio module;
- `lxc`, defaults to `/usr/bin/lxc`, used by the pulseaudio module;
- `sudo`, defaults to `/usr/bin/sudo`, used by the pulseaudio module.

As of the current moment, only the intel & hybrid intel+nvidia configurations are present within the repository, although it should be simple to customize and support an AMD or AMD+Radeon setup. Refer the the scripts in `./container_scripts` to create your own configurations, and contribute back to this repository!

> Note: Pure NVIDIA or Pure Radeon setups are also not present within the repository, but you perform a simple change within `xorg.conf.intel` to get NVIDIA support for now. I'll add in the pure NVIDIA script in the future.

## Setting up

This will take an afternoon, so get a cup of :coffee: and brace yourself.

To use ContainerTop, it must first be configured to your specific system. Container-wise, the only supported configuration is LightDM + Unity Greeter + Ubuntu MATE, so obtain other container configurations at your own risk (I've tried KDE, and it works, but you _must_ uninstall `sddm`).

Clone/download the repository, and put it somewhere easily accessible. In the root directory of the repository, you will realize that only some scripts are executable. That is intentional, as there are some scripts that have not been fully completed at the current moment.

## Mandatory Configurations

Use a text editor to modfy the following scripts based on the instructions within the section.

### `create_container.sh`

Launch a terminal emulator, and run the command `sudo evtest`. If the command is not recognized, please pull the package containing `evtest` from your package manager, and rerun the command. You should see a listing of all the events available on your computer. The events you are interested in involves the Keyboard and your pointer device (mouse or trackpad). Once you have found them, note down their paths, and test them by inputting the event number, and trying out your keyboard/pointer device.

If they correspond to the keyboard/pointer device you use, the terminal emulator should print events; otherwise, there will not be any activity on the terminal emulator. Once you have confirmed the events your keyboard and mouse uses, press CTRL+C to quit the terminal emulator.

Modify `LXC` and `ECHO` if the paths to your executable differs from the ones already configured on the script.  

Modify `KEYBOARD` and `MOUSE` to the events you have just found.

If your system does not have an NVIDIA card, omit the `nvidia-driver-XXX` package from the `DRIVERS` string. If your system uses a NVIDIA card, check the host driver version, and replace the `XXX` with that version. Please note that the host's NVIDIA driver version must be 1:1 to the container's NVIDIA driver version; if you are using a non-standard version number, you must manually install the NVIDIA driver on the container in your own accord.

Save the script.

### `desktop_enter_vt.sh`

This script will be run as root, so all commands effectively have sudo.

If your host does not use the GNOME Display Manager, or does not use `service`, please change `LOGIN_MANAGER_START` and `LOGIN_MANAGER_STOP` to the commands that start and stop your login manager.

You can configure `PRE_BEGIN_HOOK`, and `POST_CHILD_HOOK` to run scripts before, and after container desktop session. `POST_BEGIN_HOOK` and `PRE_CHILD_HOOK` does not execute.

If any of your host executables, `BASH`, `ECHO`, `LXC`, `TOUCH`, `HEAD`, `PKILL` and `GREP` are different from the preconfigured paths, please change them accordingly.

If you would like to disable a module, please comment out the corresponding line within the `modules()` function. You can also create your own modules and append it to the `modules()` function, but please remember to add the ` &` (space-ampersand) at the back of the command, so that it can run as a background process.

Save the script.

### `container_scripts/xorg.conf.intel`

Run `lspci` once, and obtain the PCI address of the Intel VGA Controller. It should be in the format of `XX:XX.X`. Mentally convert this number into `pci:X:X:X`. For example: `01:02.3` should be converted to `pci:1:2:3`.

Replace the `X` and `Y` of `Option "Device" "/dev/input/eventX"` and `Option "Device" "/dev/input/eventY"` with the event numbers of the keyboard and mouse.

Replace the placeholer BusID of `BusID "pci:X:X:X"` with the PCI address you just found and mentally converted.

Save the script.

### `container_script/xorg.conf.nvidia` (For users with NVIDIA cards)

Run `lspci` once, and obtain the PCI address of the Intel VGA Controller, **and** the NVIDIA GPU Controller. They should be in the format of `XX:XX.X` and `YY:YY.Y`. Mentally convert this number to `pci:Y:Y:Y`. For example, `01:02.3` should be converted to `pci:1:2:3`.

Replace the `X` and `Y` of `Option "Device" "/dev/input/eventX"` and `Option "Device" "/dev/input/eventY"` with the event numbers of the keyboard and mouse.

Replace the placeholder BusID of `BusID "pci:Y:Y:Y"` with the NVIDIA GPU Controller's mentally converted PCI address.

Replace the placeholder BusID of `BusID "pci:X:X:X"` with the Intel VGA Controller's mentally converted PCI address.

Save the script.

### `modules/brightness.sh`

Please disable this module if you are using a desktop. This is intended for devices that have a controllable backlight.

Run `sudo evtest`, and find out which event report the events generated by the brightness keys. This is typically called "Video Bus" within the output of `sudo evtest`. Note down the event path, and test it to ensure that the event indeed reports the brightness key event. Record the events that occur as you press the brightness up/down keys.

Change `interval` to a number of your choice; the number pre-configured was selected as the screen brightness ranged from 0 to 3000.

Replace `EVTEST` with the path your host system uses for `evtest`, should it be different.

Replace the `Z` in `/dev/input/eventZ` with the number you just acquired.

Replace `event_up` and `event_down` based on with the message you just acquired; note that the asteriks at the beginning and end of the string is for expression matching.

If you are using a different backlight, change the `intel_backlight` variable to match that. Otherwise, leave it alone.

Save the script.

### `modules/pulseaudio.sh`

Change `PULSEAUDIO`, `PACTL`, `ECHO`, `LXC`, and `SUDO` to your system's configured paths if it the pre-configured values don't match.

Save the script.

## Creating a container

To create a container with a desktop environment, simply run `./create_container.sh` on any virtual terminal:

```bash
> ./create_container.sh CONTAINER_NAME -s STORAGE_POOL -n lxcbr0 -g
```

If, at any point of time, the container creation fails due to APT failing to get a certain package, then run:
```bash
> ./create_container.sh CONTAINER_NAME -i
```

## Entering a container

This is a little more complicated. Firstly, log out of all graphical user sessions; no users should be logged in. Next, switch to another terminal (or tty) using `CTRL+ALT+F<num>`, where `<num>` is anywhere between 2 to 6. Ensure that there is nothing running on those terminals before you continue.

Log into the terminal, and navigate to the root folder for ContainerTop. Run the `./desktop_enter_vt.sh` script, like so:

```bash
> sudo ./desktop_enter_vt.sh CONTAINER_NAME
```

If the container creation was done correctly, the script will end your graphical manager, and start the container's graphical manager, switching to the virtual terminal hosting the container's X11 display. Do note that due to how the script is written, PulseAudio will only work after the second time you've switched with the script since creation. Beyond the second script, everything should be working as expected.

Once you are done with the container, switch back to the terminal running the script, and press CTRL+C. This will signal to the script to terminate your container and restart the host's display manager. The script will also attempt to logout the current terminal, so that any attackers with physical access to your computer would not immediately get access to your account (and sudo, if done within 15 minutes) if they were to terminate the script.

## Cleaning up on an error

By default, the script will automatically run the cleanup section on error. However, should an unorthodoxed operation take place, and the script unexpectedly terminates (probbaly through a `kill -9` command), the user must run:

```bash
> sudo ./desktop_enter_vt.sh CONTAINER_NAME --clean
```

To stop the container's display manager and restart the host's display manager.

## Switching to NVIDIA GPU (for laptops)
At the current moment, `./switch_gpu.sh` has not been completed. However, it is possible to manually switch GPUs. These steps outline what should be done:

1. Launch a shell in the container using `lxc exec CONTAINER_NAME -- sudo --login --user ubuntu`
2. Visit `/usr/share/lightdm/`, and copy `50-greeter-wrapper.conf.nvidia` to `./lightdm.conf.d/50-greeter-wrapper.conf`
3. Visit `/etc/X11/`, and copy `xorg.conf.nvidia` to `xorg.conf`
4. Quit the shell

If done correctly, on the next container enter, the XOrg server should use the NVIDIA GPU to process graphics.

## License

This project is licensed under the [GNU General Public License v3.0](./LICENSE.md); please contribute back whatever you can!
