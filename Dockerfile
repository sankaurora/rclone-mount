ARG IMAGE_VERSION="v1.69.1"
ARG OVERLAY_VERSION="3.2.1.0"
ARG OVERLAY_ARCH="amd64"


# Builder
FROM golang:alpine AS builder

ARG IMAGE_VERSION

WORKDIR /go/src/github.com/rclone/rclone/

ENV GOPATH="/go" \
    GO111MODULE="on"

RUN apk add --no-cache --update ca-certificates go git \
    && git clone https://github.com/rclone/rclone.git \
    && cd rclone \
    && git checkout tags/${IMAGE_VERSION} \
    && go build


# Image
FROM alpine:latest

ARG OVERLAY_VERSION
ARG OVERLAY_ARCH

ENV DEBUG="false" \
    AccessFolder="/mnt" \
    RemotePath="mediaefs:" \
    MountPoint="/mnt/mediaefs" \
    ConfigDir="/config" \
    ConfigName=".rclone.conf" \
    MountCommands="--allow-other --allow-non-empty" \
    UnmountCommands="-u -z" \
    S6_BEHAVIOUR_IF_STAGE2_FAILS="2"

COPY --from=builder /go/src/github.com/rclone/rclone/rclone/rclone /usr/local/sbin/

RUN apk --no-cache upgrade \
    && apk add --no-cache --update ca-certificates fuse3 fuse fuse-dev curl xz \
    && case "${OVERLAY_ARCH}" in \
        amd64) S6_OVERLAY_ARCH="x86_64" ;; \
        arm64) S6_OVERLAY_ARCH="aarch64" ;; \
        arm/v7) S6_OVERLAY_ARCH="arm" ;; \
        arm/v6) S6_OVERLAY_ARCH="armhf" ;; \
        386) S6_OVERLAY_ARCH="i686" ;; \
        *) S6_OVERLAY_ARCH="${OVERLAY_ARCH}" ;; \
       esac \
    && echo "Installing S6 Overlay ${OVERLAY_VERSION} for ${S6_OVERLAY_ARCH}" \
    && curl -fsSL -o /tmp/s6-overlay-noarch.tar.xz \
    "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
    && curl -fsSL -o /tmp/s6-overlay-noarch.tar.xz.sha256 \
    "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-noarch.tar.xz.sha256" \
    && curl -fsSL -o "/tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" \
    "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" \
    && curl -fsSL -o "/tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz.sha256" \
    "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz.sha256" \
    && cd /tmp \
    && sha256sum -c s6-overlay-noarch.tar.xz.sha256 \
    && sha256sum -c "s6-overlay-${S6_OVERLAY_ARCH}.tar.xz.sha256" \
    && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf "/tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" \
    && apk del curl xz \
    && rm -rf /tmp/* /var/cache/apk/* /var/lib/apk/lists/*

COPY rootfs/ /

RUN chmod +x /etc/s6-overlay/scripts/* \
    /etc/s6-overlay/s6-rc.d/rclone-mount/run \
    /etc/s6-overlay/s6-rc.d/rclone-mount/finish

VOLUME ["/mnt"]

ENTRYPOINT ["/init"]

# Use this docker Options in run
# --cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined
# -v /path/to/config/.rclone.conf:/config/.rclone.conf
# -v /mnt/mediaefs:/mnt/mediaefs:shared
