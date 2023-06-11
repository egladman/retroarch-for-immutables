ARG REGISTRY=docker.io/
ARG FEDORA_VERSION=38
ARG RETROARCH_STAGE=retroarch-rafi
ARG XDG_CONFIG_HOME=/app
ARG XDG_STATE_HOME=/app
ARG XDG_DATA_HOME=/app


FROM ${REGISTRY}fedora:${FEDORA_VERSION} as fedora

RUN set -eux; \
    dnf update -y

FROM fedora as runtime-rootfs-build

ARG FEDORA_VERSION

RUN set -eux; \
    dnf install \
      --releasever=$FEDORA_VERSION \
      --setopt=install_weak_deps=False \
      --assumeyes \
      --installroot=/rootfs \
      bash \
      glslang \
      libaio \
      libatomic \
      libdecor \
      libgcc \
      libglvnd-glx \
      libglvnd-opengl \
      libpng \
      libunwind \
      libusb \
      libstdc++ \
      libwayland-client \
      libwayland-cursor \
      libwayland-egl \
      libX11 \
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
      soundtouch \
      spirv-tools-libs \
      vulkan \
      xz-lzma-compat \
      xz \
      zlib \
    ;


FROM fedora as devel-rootfs-build

ARG FEDORA_VERSION

# Reuse packages installed in previous stage to save time
COPY --from=runtime-rootfs-build /rootfs /rootfs

RUN set -eux; \
    dnf install \
      --releasever=$FEDORA_VERSION \
      --setopt=install_weak_deps=False \
      --assumeyes \
      --installroot=/rootfs \
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
      lld \
      make \
      mbedtls-devel \
      mesa-libEGL-devel \
      #minizip-devel \
      minizip-compat-devel \
      nasm \
      ninja-build \
      openssl-devel \
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
      wayland-devel \
      wayland-protocols-devel \
      xxd \
      xxhash-devel \
      xz-devel \
      zlib-devel \
    ;


# No Operation
FROM scratch as retroarch-noop-build

FROM fedora as retroarch-rafi-build

COPY --from=devel-rootfs-build /rootfs /

WORKDIR /rootfs/src

COPY . .

ARG DEBUG=1
ARG XDG_CONFIG_HOME
ARG XDG_STATE_HOME
ARG XDG_DATA_HOME

RUN set -eux; \
    DESTDIR= ./main bootstrap install; \
    ./main install @retroarch
#    mv "$XDG_CONFIG_HOME" "/rootfs/${XDG_CONFIG_HOME}"; \
#    find "/rootfs${XDG_DATA_HOME}/rafi" -name src -type d -exec rm -rv {} + || true; \
#    chown -R 4826:4826 /rootfs/*


FROM ${RETROARCH_STAGE}-build as retroarch-target-build

FROM scratch as runtime-shared

ARG XDG_CONFIG_HOME
ARG XDG_STATE_HOME
ARG XDG_DATA_HOME

ENV XDG_CONFIG_HOME=$XDG_CONFIG_HOME
ENV XDG_STATE_HOME=$XDG_STATE_HOME
ENV XDG_DATA_HOME=$XDG_DATA_HOME
ENV XDG_RUNTIME_DIR=/dev/shm


FROM runtime-shared as runtime-devel

COPY --from=devel-rootfs-build /rootfs /
COPY --from=retroarch-target-build /rootfs /

#RUN set -eux; \
#    ln -sv /src/main /bin/rafi

WORKDIR /app/retroarch

USER 4826

ENTRYPOINT [ "/src/entrypoint.sh" ]
CMD [ "retroarch" ]


FROM runtime-shared as runtime-vanilla

COPY --from=runtime-rootfs-build /rootfs /
COPY --from=retroarch-target-build /rootfs /

RUN set -eux; \
    ln -sv /src/main /bin/rafi

WORKDIR /app/retroarch

USER 4826

ENTRYPOINT [ "/src/entrypoint.sh" ]
CMD [ "retroarch" ]