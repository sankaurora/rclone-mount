#!/bin/sh

set -eu

. /etc/rclone-mount-lib.sh

CONFIG_PATH="$(config_path)"

if [ ! -f "${CONFIG_PATH}" ]; then
    echo "missing rclone config at ${CONFIG_PATH}" >&2
    exit 1
fi

if ! rclone_process_present; then
    echo "rclone process is not running" >&2
    exit 1
fi

if ! mount_present; then
    echo "expected mount is missing at ${MountPoint}" >&2
    exit 1
fi
