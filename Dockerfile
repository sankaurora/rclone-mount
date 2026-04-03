# syntax=docker/dockerfile:1

ARG IMAGE_VERSION="v1.69.1"
ARG OVERLAY_VERSION="3.2.1.0"
ARG OVERLAY_ARCH="amd64"
ARG ALPINE_VERSION="3.22"

# Builder
FROM --platform=$BUILDPLATFORM golang:alpine AS builder

ARG IMAGE_VERSION
ARG TARGETARCH
ARG TARGETOS

ENV CGO_ENABLED="0" \
    GOBIN="/out" \
    GO111MODULE="on" \
    GOCACHE="/root/.cache/go-build"

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    GOOS="${TARGETOS:-linux}" GOARCH="${TARGETARCH:-amd64}" \
    go install -trimpath -ldflags="-s -w -buildid=" github.com/rclone/rclone@${IMAGE_VERSION}

FROM alpine:${ALPINE_VERSION} AS s6-overlay

ARG OVERLAY_VERSION
ARG OVERLAY_ARCH
ARG TARGETARCH
ARG TARGETVARIANT

RUN apk add --no-cache curl xz \
    && if [ -n "${TARGETARCH:-}" ]; then \
        TARGET_ID="${TARGETARCH}"; \
        if [ -n "${TARGETVARIANT:-}" ]; then TARGET_ID="${TARGET_ID}/${TARGETVARIANT}"; fi; \
      else \
        TARGET_ID="${OVERLAY_ARCH}"; \
      fi \
    && case "${TARGET_ID}" in \
        amd64) S6_OVERLAY_ARCH="x86_64" ;; \
        arm64) S6_OVERLAY_ARCH="aarch64" ;; \
        arm/v7) S6_OVERLAY_ARCH="arm" ;; \
        arm/v6) S6_OVERLAY_ARCH="armhf" ;; \
        386) S6_OVERLAY_ARCH="i686" ;; \
        *) S6_OVERLAY_ARCH="${TARGET_ID}" ;; \
       esac \
    && echo "Installing S6 Overlay ${OVERLAY_VERSION} for ${S6_OVERLAY_ARCH}" \
    && mkdir -p /overlay-rootfs \
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
    && tar -C /overlay-rootfs -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C /overlay-rootfs -Jxpf "/tmp/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz"

# Image
FROM alpine:${ALPINE_VERSION}

ENV DEBUG="false" \
    AccessFolder="/mnt" \
    RemotePath="mediaefs:" \
    MountPoint="/mnt/mediaefs" \
    ConfigDir="/config" \
    ConfigName=".rclone.conf" \
    MountCommands="--allow-other --allow-non-empty" \
    UnmountCommands="-u -z" \
    S6_BEHAVIOUR_IF_STAGE2_FAILS="2"

COPY --from=builder /out/rclone /usr/local/sbin/rclone
COPY --from=s6-overlay /overlay-rootfs/ /

COPY rootfs/ /

RUN apk add --no-cache ca-certificates fuse3 \
    && ln -sf /usr/bin/fusermount3 /usr/bin/fusermount \
    && chmod +x /etc/s6-overlay/scripts/* \
    /etc/s6-overlay/s6-rc.d/rclone-mount/run \
    /etc/s6-overlay/s6-rc.d/rclone-mount/finish

VOLUME ["/mnt"]

ENTRYPOINT ["/init"]

# Use this docker Options in run
# --cap-add SYS_ADMIN --device /dev/fuse --security-opt apparmor:unconfined
# -v /path/to/config/.rclone.conf:/config/.rclone.conf
# -v /mnt/mediaefs:/mnt/mediaefs:shared
