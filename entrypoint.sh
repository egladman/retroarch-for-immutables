#!/usr/bin/env bash

base_dir=/app

set -o allexport -o errexit
XDG_CONFIG_HOME="$base_dir"
XDG_STATE_HOME="$base_dir"
XDG_DATA_HOME="$base_dir"
XDG_RUNTIME_DIR=/tmp
unset base_dir
set +o allexport # Disable

eval "$(rafi init bash)"

exec "$@"
