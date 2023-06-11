#!/usr/bin/env bash

set -o errexit

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

if [[ "$PATH" != "/app/rafi/rootfs"* ]]; then
    printf '%s\n' "Modifying PATH"
    PATH="/app/rafi/rootfs/bin:${PATH}"
fi

if [[ "$LD_LIBRARY_PATH" != "/app/rafi/rootfs"* ]]; then
    printf '%s\n' "Modifying LD_LIBRARY_PATH"
    LD_LIBRARY_PATH="/app/rafi/rootfs/lib64:/app/rafi/rootfs/lib"
fi
set +o allexport

for d in "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"; do
    if [[ -d "$d" ]]; then
	continue
    fi
    printf '%s\n' "Creating directory: $d"
    mkdir -p "$d"
done

printf '%s\n' "Entrypoint complete. Executing: $*"
exec "$@"
