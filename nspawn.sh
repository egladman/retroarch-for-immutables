#!/usr/bin/env sh

set -o errexit

# Systemd-nspawn Wrapper written in POSIX shell to dynamically set bind mounts.
# This not security hardened (i.e, we're mounting the entire /home, and portions of
# /etc into the container). This is done for the sake of convience, and will be
# addressed later down the line. Stay tuned...

# Currently all logs are written to stderr. Why you may ask? Originally this script
# generated the systemd-nspawn command, but did not execute it. So you could do `eval $(./launch.sh)`
log_err() {
    printf '%s\n' "$*" >&2
}

if [ -z "$1" -o ! -e "$1" ] ; then
    log_err "OCI bundle was not specified or the path does not exist."
    exit 128
fi

oci_bundle="$(readlink -f "$1")"

# Support appending args to nspawn command
while [ "$#" -gt 0 ]; do
    case "$1" in
	--)
	    shift
	    extra_argv="$*"
	    set -- # Clear
	    break
	    ;;
    esac
    shift
done

# Find display server
if [ -n "$WAYLAND_DISPLAY" ]; then
    log_err "Found display server: Wayland"
    set -- "$@" --bind-ro="/tmp/${WAYLAND_DISPLAY}:/tmp/${WAYLAND_DISPLAY}" --setenv=WAYLAND_DISPLAY
elif [ -n "$DISPLAY" ]; then
    log_err "Found display server: X11"
    # X11 does not respect the xdg runtime variable
    # We must explicity set DISPLAY since systemd-nspawn is invoked by pkexec.
    # Simply doing --setenv=DISPLAY will not work .
    set -- "$@" --bind-ro="/tmp/.X11-unix:/tmp/.X11-unix" --setenv=DISPLAY="$DISPLAY"

    xauth_file="/tmp/.retroarch-rafi-xauth"
    xauth nextract - "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$xauth_file" nmerge -
    set -- "$@" --bind="$xauth_file" --setenv=XAUTHORITY="$xauth_file"    
else
    log_err "Could not find Wayland or X11 display server."
    exit 128
fi

# Find graphics devices. This should work with most gpu vendors
found_nvidia=0
for d in /dev/nvidia* /dev/dri /dev/input; do
    if [ ! -c "$d" -o ! -d "$d" ]; then
	continue
    fi
 
    case "$d" in
	"/dev/nvidia"*)
	    found_nvidia=1
	    ;;
	"/dev/dri")
	    # Do not attempt to mount any other grahics devices once nvidia hardware is found
	    if [ $found_nvidia -eq 1 ]; then
		continue
	    fi
	    ;;
    esac

    log_err "Found character device: $d"
    set -- "$@" --bind="$d" --property=DeviceAllow="$d rwm"
done

# TODO: I should be-able to use --bind-user= instead of mounting /etc/{passwd,group} into the container. I wasn't successful with my first attempt
set -- "$@" --user="${USER:?}" --bind="/home/${USER:?}" --bind-ro="/etc/group" --bind-ro="/etc/passwd" --machine=retroarch-immutable --oci-bundle="$oci_bundle"

log_err "Using options: $*"

"${EXECCOMMAND-pkexec}" systemd-nspawn "$@" $extra_argv
