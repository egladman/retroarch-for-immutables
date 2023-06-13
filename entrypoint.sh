#!/usr/bin/env bash

set -o errexit

# Exporting environment variables in the entrypoint might look
# like an anti-pattern, but there's a good reason. This ensures
# compatibility with both docker and oci images.

res="$(id -nu)"
regex='^[0-9]+$'
base_dir="/dev/shm/${res}"
if [[ ! "$res" =~ $regex ]] && [[ "$res" != "root" ]]; then
    base_dir="/home/${res}"
fi

xdg_config_home_fallback="${base_dir}/.config"
xdg_state_home_fallback="${base_dir}/.local/state"
xdg_data_home_fallback="${base_dir}/.local/share"

set -o allexport
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$xdg_config_home_fallback}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$xdg_state_home_fallback}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$xdg_data_home_fallback}"
XDG_RUNTIME_DIR="/tmp"

RAFI_RUNTIME_ROOT="/app/data/rafi/rootfs"
PATH="${RAFI_RUNTIME_ROOT:?}/bin:${RAFI_RUNTIME_ROOT:?}/usr/bin:${PATH}"
LD_LIBRARY_PATH="${RAFI_RUNTIME_ROOT:?}/lib64:${RAFI_RUNTIME_ROOT:?}/lib:${RAFI_RUNTIME_ROOT:?}/usr/lib64:${RAFI_RUNTIME_ROOT:?}/usr/lib:${LD_LIBRARY_PATH}"
set +o allexport

for d in "${XDG_CONFIG_HOME}/retroarch" "$XDG_STATE_HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"; do
    if [[ -d "$d" ]]; then
	continue
    fi
    printf 'Entrypoint: %s\n' "Creating directory: $d"
    mkdir -p "$d"
done

read -r -d '' conf <<-EOF || true
config_save_on_exit = "true"

libretro_directory = "/app/data/rafi/rootfs/usr/lib/libretro"
libretro_info_path = "/app/data/rafi/rootfs/usr/share/libretro/info"
assets_directory = "/app/data/rafi/rootfs/usr/share/libretro/assets"
joypad_autoconfig_dir = "/app/data/rafi/rootfs/usr/share/libretro/autoconfig"

EOF

retroarch_conf="${XDG_CONFIG_HOME}/retroarch/retroarch.overrides.cfg"
if [[ ! -f "$retroarch_conf" ]]; then
    printf 'Entrypoint: %s\n' "Generating retroarch config: $retroarch_conf"
    printf '%s\n' "$conf" > "$retroarch_conf"
fi

printf 'Entrypoint: %s\n' "Setting working directory: $XDG_CONFIG_HOME"
cd "$XDG_CONFIG_HOME"


case "$1" in
    retroarch)
	set -- "$@" --appendconfig "$retroarch_conf"
	;;
esac

printf 'Entrypoint: %s\n' "Complete. Executing: $*"
exec "$@"
