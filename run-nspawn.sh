#!/usr/bin/env sh

set -o errexit

# Systemd-nspawn wrapper written in POSIX shell to dynamically set bind mounts.
# This not security hardened (i.e, we're mounting the entire /home, and portions of
# /etc into the container). This is done for the sake of convience, and will be
# addressed later down the line. Stay tuned...

DRYRUN=0

# Currently all logs are written to stderr. Why you may ask? Originally this script
# generated the systemd-nspawn command, but did not execute it. So you could do `eval $(./launch.sh)`
log_err() {
    printf '%s\n' "$*" >&2
}

log_fatal() {
    log_err "$*"
    exit 1
}

usage(){
    cat <<-EOF
retroarch-for-immutables systemd-nspawn wrapper

Usage: ./run-nspawn.sh [options...] <path/to/oci/bundle>

Options

-h,--help,help
    Print this text
-u,--dry-run
    Print generated command rather than executing it

Environment

RUNEXEC
    Command used to elevate privileges. Defaults to 'pkexec'.

EOF
}

# Support appending args to nspawn command
while [ "$#" -gt 0 ]; do
    case "$1" in
	-u|--dry-run)
	    DRYRUN=1
	    ;;
	''|-h|--help|help)
	    usage
	    exit 0
	    ;;
	--)
	    shift
	    extra_argv="$*"
	    set -- # Clear
	    break
	    ;;
	-*)
	    log_fatal "Unknown option: $1"
	    ;;
	*)
	    OCIBUNDLE="$(readlink -f "$1")"
	    ;;
    esac
    shift
done

if [ ! -e "$OCIBUNDLE" ]; then
    log_fatal "OCI bundle does not exist or was never passed."
fi

# Find display server
case "$XDG_SESSION_TYPE" in
    "wayland")
	set -- "$@" --bind-ro="/tmp/${WAYLAND_DISPLAY:?}" --setenv=WAYLAND_DISPLAY
	;;
    "x11")
	# We must explicity set DISPLAY since systemd-nspawn is invoked by pkexec.
	# Simply doing --setenv=DISPLAY will not work .
	set -- "$@" --bind-ro="/tmp/.X11-unix" --setenv=DISPLAY="${DISPLAY:?}"

	xauth_file="/tmp/.retroarch-xauth"
	xauth nextract - "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$xauth_file" nmerge -
	set -- "$@" --bind="$xauth_file" --setenv=XAUTHORITY="$xauth_file"    
	;;
    *)
	log_fatal "Unable to determine display server. Variable XDG_SESSION_TYPE is empty or not set."
	;;
esac

# Find pulse server
for f in "${XDG_RUNTIME_DIR:-/tmp}/pulse/native"; do
    if [ ! -S "$f" ]; then
	continue
    fi

    # Always bind mount to /tmp inside the container. Must match
    # XDG_RUNTIME_DIR declared in the entrypoint  
    set -- "$@" --bind-ro="${f}:/tmp/${f##*/}" --setenv=PULSE_SERVER="unix:/tmp/${f##*/}"
    break
done

# Find graphics devices. This should work with most gpu vendors
found_nvidia=0
for d in /dev/nvidia* /dev/dri /dev/input /dev/snd; do    
    if [ ! -c "$d" -a ! -d "$d" ]; then
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
    set -- "$@" --bind="$d" #--property=eviceAllow="$d rwm"
done

# Allow devices
# Namees are derived from /proc/devices
# https://www.kernel.org/doc/html/latest/admin-guide/devices.html
allow_chars="usb_device input"
if [ $found_nvidia -eq 1 ]; then
    allow_chars="$allow_chars $(cat /proc/devices | grep nvidia | cut -d' ' -f2)" 
fi

for c in $allow_chars; do
    case "$c" in
	usb_device|input)
	    c="$c rwm"
	    ;;
	nvidia*)
	    if [ $found_nvidia -eq 0 ]; then
		continue
	    fi
	    ;;
    esac
    set -- "$@" --property=DeviceAllow="char-$c"
done

# TODO: I should be-able to use --bind-user= instead of mounting /etc/{passwd,group} into the container. I wasn't successful with my first attempt
set -- "$@" --user="${USER:?}" --bind="/home/${USER:?}" --bind-ro="/etc/group" --bind-ro="/etc/passwd" --machine=retroarch --oci-bundle="$OCIBUNDLE"

if [ $DRYRUN -eq 1 ]; then
    RUNEXEC="echo"
fi

"${RUNEXEC-pkexec}" systemd-nspawn "$@" $extra_argv
