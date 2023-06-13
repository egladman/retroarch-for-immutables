ARG REGISTRY=docker.io/
ARG FEDORA_VERSION=38
ARG RETROARCH_STAGE=retroarch-rafi
ARG INSTALL_PREFIX=/app
ARG INSTALL_DESTDIR=/rootfs

FROM ${REGISTRY}fedora:${FEDORA_VERSION} as fedora

RUN set -eux; \
    dnf update -y

FROM fedora as runtime-rootfs-build

ARG FEDORA_VERSION
ARG INSTALL_DESTDIR

RUN set -eux; \
    dnf install \
      --releasever=$FEDORA_VERSION \
      --setopt=install_weak_deps=False \
      --assumeyes \
      --installroot="$INSTALL_DESTDIR" \
      alsa-lib\
      bash \
      flac \
      freetype \
      glslang \
      glx-utils \
      libaio \
      libatomic \
      libavcodec-free \
      libavformat-free \
      libavutil-free \
      libappstream-glib \
      libdecor \
      libgcc \
      libglvnd-glx \
      libglvnd-opengl \
      libpcap \
      libpng \
      libunwind \
      libusb1 \
      libstdc++ \
      libswscale-free \
      libswresample-free \
      libwayland-client \
      libwayland-cursor \
      libwayland-egl \
      libX11 \
      libXxf86vm \
      libxcb \
      libXext \
      libXinerama \
      libxkbcommon \
      libxml2 \
      libXrandr \
      libXv \
      mbedtls \
      mesa-dri-drivers \
      mesa-libEGL \
      minizip-compat \
      openal-soft \
      pulseaudio-libs \
      SDL2 \
      soundtouch \
      spirv-tools-libs \
      vulkan \
      xrandr \
      xxhash-libs \
      xz-lzma-compat \
      xz \
      zlib \
    ;

FROM fedora as devel-rootfs-build

ARG FEDORA_VERSION
ARG INSTALL_DESTDIR

# Reuse packages installed in previous stage to save time
COPY --from=runtime-rootfs-build $INSTALL_DESTDIR $INSTALL_DESTDIR

RUN set -eux; \
    dnf install \
      --releasever=$FEDORA_VERSION \
      --setopt=install_weak_deps=False \
      --assumeyes \
      --installroot="$INSTALL_DESTDIR" \
      alsa-lib-devel \      
      automake \
      autoconf \
      ccache \
      clang \
      cmake3 \
      diffutils \
      ffmpeg-free-devel \
      fmt-devel \
      gcc \
      gcc-c++ \
      git \
      glslang-devel \
      libaio-devel \
      libpcap-devel \
      libpng-devel \
      libusb-compat-0.1 \
      libusb1-devel \
      libavcodec-free-devel \
      libavdevice-free-devel \
      libavformat-free-devel \
      libavutil-free-devel \
      libswresample-free-devel \
      libswscale-free-devel \
      libXxf86vm-devel \
      lld \
      make \
      mbedtls-devel \
      mesa-libEGL-devel \
      #minizip-devel \
      minizip-compat-devel \
      nasm \
      ninja-build \
      openal-soft-devel \
      openssl-devel \
      pulseaudio-libs-devel \
      libdbusmenu-devel \
      libtool \
      libzip \
      patch \
      python \
      SDL2-devel \
      spirv-tools-libs \
      soundtouch-devel \
      #libudev
      systemd-devel \
      tree \
      vim \
      vulkan-headers \
      vulkan-devel \
      vulkan-tools \
      wayland-devel \
      wayland-protocols-devel \
      xxd \
      xxhash-devel \
      xz-devel \
      zlib-devel \
    ;

FROM fedora as rafi-rootfs-build

ARG RAFI_GIT_REF=b1df048fbb48d8ddaa73d1162475d46b4829f6f8
ARG INSTALL_DESTDIR
COPY --from=devel-rootfs-build $INSTALL_DESTDIR /

WORKDIR ${INSTALL_DESTDIR}/src/rafi
RUN set -eux; \
    git config --global url."https://github.com/egladman".insteadOf "git@github.com:egladman"; \
    git clone --recursive https://github.com/egladman/rafi.git .; \
    git checkout $RAFI_GIT_REF

# No Operation
FROM scratch as retroarch-noop-build

ARG INSTALL_DESTDIR
COPY --from=rafi-rootfs-build $INSTALL_DESTDIR $INSTALL_DESTDIR

FROM fedora as retroarch-rafi-build

ARG INSTALL_DESTDIR
COPY --from=devel-rootfs-build $INSTALL_DESTDIR /
COPY --from=rafi-rootfs-build $INSTALL_DESTDIR /

WORKDIR /src/rafi

ARG DEBUG=1
ARG INSTALL_DESTDIR
ARG INSTALL_PREFIX
ARG XDG_CONFIG_HOME="${INSTALL_PREFIX}/config"
ARG XDG_STATE_HOME="${INSTALL_PREFIX}/state"
ARG XDG_DATA_HOME="${INSTALL_PREFIX}/data"

RUN set -eux; \
    mkdir -p $INSTALL_DESTDIR; \
    DESTDIR= ./main bootstrap install; \
    ./main install @retroarch; \
    # Delete all package source code
    find "${XDG_DATA_HOME}/rafi/pkgs" -maxdepth 2 -name 'src' -type d -exec rm -rf "{}" \; ; \
    mv $INSTALL_PREFIX ${INSTALL_DESTDIR}${INSTALL_PREFIX};

FROM ${RETROARCH_STAGE}-build as retroarch-target-build
FROM scratch as runtime-shared

COPY /entrypoint.sh /entrypoint

ENTRYPOINT [ "/entrypoint" ]
CMD [ "retroarch" ]

FROM runtime-shared as runtime-devel

ARG INSTALL_DESTDIR
COPY --from=devel-rootfs-build $INSTALL_DESTDIR /
COPY --from=retroarch-target-build $INSTALL_DESTDIR /

USER 0

FROM runtime-shared as runtime-vanilla

ARG INSTALL_DESTDIR
COPY --from=runtime-rootfs-build $INSTALL_DESTDIR /
COPY --from=retroarch-target-build $INSTALL_DESTDIR /

USER 4826