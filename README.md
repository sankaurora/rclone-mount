[rcloneurl]: https://rclone.org

[![rclone.org](https://rclone.org/img/logo_on_dark__horizontal_color.svg)][rcloneurl]

## Rclone Mount Container

Lightweight and simple container image with compiled `rclone` (https://github.com/ncw/rclone). The runtime image uses Alpine with a stripped static `rclone` binary, `fuse3`, and `s6-overlay`. Mount your cloud storage like google drive inside a container and make it available to other containers like your Plex Server or on your hostsystem (mount namespace on the host is shared). You need a working rclone.conf (from another host or create it inside the container with entrypoint /bin/sh). all rclone remotes can be used.

The Container uses `s6-overlay` with `s6-rc` to handle docker stop/restart ( `fusermount -uz $MountPoint` is applied on app crashes also) and also preparing the mountpoint.

## GitHub Actions

The repository includes a GitHub Actions workflow at `.github/workflows/build-latest-rclone.yml`. It resolves the latest upstream `rclone` release, builds the container image with that version, and publishes `latest` plus the upstream `vX.Y.Z` tag to `ghcr.io/<owner>/<repo>`.

# Usage Example:

    docker run -d --name rclone-mount \
        --restart=unless-stopped \
        --cap-add SYS_ADMIN \
        --device /dev/fuse \
        --security-opt apparmor:unconfined \
        -e RemotePath="mediaefs:" \
        -e MountCommands="--allow-other --allow-non-empty" \
        -v /path/to/config:/config \
        -v /host/mount/point:/mnt/mediaefs:shared \
        ghcr.io/<owner>/<repo>:latest

> mandatory docker commands:

- --cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined

> needed volume mappings:

- -v /path/to/config:/config
- -v /host/mount/point:/mnt/mediaefs:shared

# Environment Variables:

| Variable                                          |     | Description                                                                                                                       |
| ------------------------------------------------- | --- | --------------------------------------------------------------------------------------------------------------------------------- |
| `RemotePath`="mediaefs:path"                      |     | remote name in your rclone config, can be your crypt remote: + path/foo/bar                                                       |
| `MountPoint`="/mnt/mediaefs"                      |     | #INSIDE Container: needs to match mapping -v /host/mount/point:`/mnt/mediaefs:shared`                                             |
| `ConfigDir`="/config"                             |     | #INSIDE Container: -v /path/to/config:/config                                                                                     |
| `ConfigName`=".rclone.conf"                       |     | #INSIDE Container: /config/.rclone.conf                                                                                           |
| `MountCommands`="--allow-other --allow-non-empty" |     | default mount commands, (if you not parse anything, defaults will be used)                                                        |
| `UnmountCommands`="-u -z"                         |     | default unmount commands                                                                                                          |
| `AccessFolder`="/mnt"                             |     | access with --volumes-from rclone-mount, changes of AccessFolder have no impact because its the exposed folder in the dockerfile. |

## Use your own MountCommands with:

```vim
-e MountCommands="--allow-other --allow-non-empty --dir-cache-time 48h --poll-interval 5m --buffer-size 128M"
```

All Commands can be found at [https://rclone.org/commands/rclone_mount/](https://rclone.org/commands/rclone_mount/). Use `--buffer-size 256M` (dont go too high), when you encounter some "Direct Stream" problems on Plex Server for example.

## Troubleshooting:

When you force remove the container, you have to `sudo fusermount3 -u -z /host/mount/point` on the hostsystem (or `fusermount` on hosts that still provide the legacy name).

## Todo

- [ ] more settings
- [ ] Auto Update Function
- [ ] launch with specific USER_ID
