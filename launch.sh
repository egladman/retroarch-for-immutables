#!/usr/bin/env sh

set -o errexit

# Wrapper for systemd-nspawn to dynamically set bind mounts. We're stripping away much
# of the benefits of containerization for the sake of convenience.

log_err() {
    printf '%s\n' "$*" >&2
}

if [ -z "$1" -o ! -e "$1" ] ; then
    log_err "OCI bundle was not specified or the path does not exist."
    exit 128
fi

oci_bundle="$(readlink -f "$1")"
run_dir="${XDG_RUNTIME_DIR:-/tmp}"
data_dir="${XDG_DATA_DIR:-$HOME/.local/share}"
saves_dir="${data_dir}/retroarch-rafi/saves"
states_dir="${data_dir}/retroarch-rafi/states"

for f in "$saves_dir" "$states_dir"; do
    if [ ! -d "$f" ]; then
	mkdir -p "$f"
	log_err "Created directory: $f"
    fi
done

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
    set -- "$@" --bind-ro="${run_dir}/${WAYLAND_DISPLAY}:/tmp/${WAYLAND_DISPLAY}" --setenv=WAYLAND_DISPLAY
elif [ -n "$DISPLAY" ]; then
    log_err "Found display server: X11"
    # X11 does not respect xdg runtime variable
    # We must explicity set DISPLAY since systemd-nspawn is invoked by pkexec.
    # Simply doing --setenv=DISPLAY will not work .
    set -- "$@" --bind-ro="/tmp/.X11-unix:/tmp/.X11-unix" --setenv=DISPLAY="$DISPLAY"

    xauth_file="${run_dir}/.retroarch-rafi-xauth"
    xauth nextract - "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$xauth_file" nmerge -
    set -- "$@" --bind="$xauth_file" --setenv=XAUTHORITY="$xauth_file"    
else
    log_err "Could not find Wayland or X11 display server."
    exit 128
fi

# Find graphics devices
for d in /dev/nvidia* /dev/dri/*; do
    if [ ! -c "$d" ]; then
	continue
    fi
    log_err "Found character device: $d"
    set -- "$@" --bind="$d" #--property=DeviceAllow=\"char-${d##*/} rwm\"
done

set -- "$@" --bind-ro=/etc/group --bind-ro=/etc/passwd --bind="${HOME:?}" --user="${USER:?}" --machine=retroarch-rafi --oci-bundle="$oci_bundle" --bind="${saves_dir}:/app/retroarch/saves" --bind="${states_dir}:/app/retroarch/states"

log_err "Using options: $*"

"${SU_COMMAND-pkexec}" systemd-nspawn "$@" $extra_argv
