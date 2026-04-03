#!/bin/sh

config_path() {
    printf '%s/%s' "${ConfigDir%/}" "${ConfigName#/}"
}

mount_present() {
    awk -v remote="${RemotePath}" -v mountpoint="${MountPoint}" '
        $1 == remote && $2 == mountpoint { found = 1; exit }
        END { exit found ? 0 : 1 }
    ' /proc/mounts
}

rclone_process_present() {
    if command -v pidof >/dev/null 2>&1; then
        pidof rclone >/dev/null 2>&1
        return $?
    fi

    ps | grep '[r]clone' >/dev/null 2>&1
}
